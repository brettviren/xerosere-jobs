// noise_spectra.cpp -- Phlex plugin: fold voltage-level WCT frames into
// per-channel-group mean noise amplitude spectra.
//
// This is the Phlex-native replacement for WCT's SigProc::NoiseModeler (an
// IFrameSink + ITerminal that writes its result at finalize()).  It reuses
// WCT's own spectral estimator, Aux::NoiseTools::Collector, one per channel
// group, inside a Phlex fold, and reproduces NoiseModeler::finalize() to make
// the output.
//
// Nodes:
//   fold    "xsj_noise_fold"   : wcphlex::Frame (input_layer) -> xsj::SpectraCollector
//                                (partition), whose result() is xsj::NoiseSpectra
//   observe "xsj_noise_json"   : writes NoiseSpectra as a WCT noise-spectra file
//                                (the format EmpiricalNoiseModel/GroupNoiseModel read)
//   transform "xsj_noise_table": NoiseSpectra -> phlex_arrow::TableGroup, for
//                                phlex_arrow_hdf_output
//
// Config (all optional except input_creator):
//   input_creator (string)  creator of the frame product (eg a wcph island label)
//   input_layer   (string)  "event"
//   input_suffix  (string)  "frame"
//   partition     (string)  "job": the layer at which spectra are produced
//   tag           (string)  "": trace tag; "" uses the untagged traces
//   groups        (string)  "": WCT channel-groups file (array of {groupID,
//                           channels}); "" puts every channel in group 0
//   nfft          (int)     0: collection size; 0 = the first trace's length
//   nhalfout      (int)     0: output half-spectrum size; 0 = ceil(sqrt(nfft))
//   maxdev        (double)  0: if > 0, skip traces with more than
//                           (1-threshold) of samples further than maxdev from
//                           the median (WCT NoiseRanker), in WCT units (volts)
//   threshold     (double)  0.9: NoiseRanker rank threshold
//   output_file   (string)  "": write the WCT noise file here (.json or .json.bz2)
//   table         (string)  "noise_spectra": table and product suffix for HDF5

#include "wire_cell_phlex/Data.hpp"

#include "WireCellAux/FftwDFT.h"
#include "WireCellAux/FrameTools.h"
#include "WireCellAux/NoiseTools.h"
#include "WireCellUtil/Interpolate.h"
#include "WireCellUtil/Persist.h"

#include "arrow_ntuple/Record.hpp"
#include "phlex_arrow_common/TableGroup.hpp"

#include "phlex/module.hpp"

#include <algorithm>
#include <cmath>
#include <map>
#include <memory>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>

namespace xsj {

    // One channel group's spectrum, as in a WCT noise-spectra file entry.
    struct GroupSpectrum {
        std::int32_t group;
        double period;           // sampling period (WCT units)
        std::int32_t nsamples;   // ticks of the original waveforms
        std::int32_t nwaves;     // waveforms collected
        std::int32_t nfft;       // collection size
        std::vector<float> freqs;
        std::vector<float> amps;
    };

    // The fold product.
    struct NoiseSpectra {
        std::vector<GroupSpectrum> groups;
    };

    struct CollectorOptions {
        std::string tag;
        std::map<int, int> chgrp;  // channel -> group
        std::size_t nfft{0};
        std::size_t nhalfout{0};
        double maxdev{0};
        double threshold{0.9};
    };

    // The fold accumulator: one WCT Collector per channel group.
    class SpectraCollector {
      public:
        explicit SpectraCollector(CollectorOptions opts)
          : m_opts(std::move(opts))
          , m_dft(std::make_shared<WireCell::Aux::FftwDFT>())
        {
        }

        void add(WireCell::IFrame::pointer const& frame)
        {
            if (!frame) return;
            auto traces = m_opts.tag.empty() ? WireCell::Aux::untagged_traces(frame)
                                             : WireCell::Aux::tagged_traces(frame, m_opts.tag);
            if (traces.empty()) return;
            if (m_tick == 0) m_tick = frame->tick();
            for (auto const& trace : traces) {
                auto const& wave = trace->charge();
                if (wave.empty()) continue;
                if (m_nfft == 0) m_nfft = m_opts.nfft ? m_opts.nfft : wave.size();
                if (m_nhalfout == 0)
                    m_nhalfout = m_opts.nhalfout ? m_opts.nhalfout
                                                 : static_cast<std::size_t>(std::ceil(std::sqrt(m_nfft)));
                if (!is_noise(wave)) continue;
                collector(trace->channel()).add(wave.begin(), wave.end());
            }
        }

        // As WCT SigProc::NoiseModeler::finalize().
        NoiseSpectra result() const
        {
            NoiseSpectra out;
            const std::size_t nout = 2 * m_nhalfout;
            for (auto const& [gid, col] : m_gcol) {
                if (col.nwaves() == 0) continue;
                auto camps = col.amplitude();
                const double Fcol = 1.0 / (m_tick * m_nfft);
                const double Fout = 1.0 / (m_tick * nout);
                WireCell::linterp<float> terp(camps.begin(), camps.end(), 0, Fcol);
                GroupSpectrum gs{.group = gid,
                                 .period = m_tick,
                                 .nsamples = static_cast<std::int32_t>(col.nticks()),
                                 .nwaves = static_cast<std::int32_t>(col.nwaves()),
                                 .nfft = static_cast<std::int32_t>(m_nfft),
                                 .freqs = std::vector<float>(m_nhalfout),
                                 .amps = std::vector<float>(m_nhalfout)};
                terp(gs.amps.begin(), m_nhalfout, 0, Fout);
                for (std::size_t i = 0; i < m_nhalfout; ++i) gs.freqs[i] = i * Fout;
                out.groups.push_back(std::move(gs));
            }
            return out;
        }

      private:
        using Collector = WireCell::Aux::NoiseTools::Collector;

        bool is_noise(std::vector<float> const& wave) const
        {
            if (m_opts.maxdev <= 0) return true;
            std::vector<float> tmp(wave);
            auto mid = tmp.begin() + tmp.size() / 2;
            std::nth_element(tmp.begin(), mid, tmp.end());
            const float med = *mid;
            std::size_t outliers = 0;
            for (float v : wave)
                if (std::abs(v - med) > m_opts.maxdev) ++outliers;
            const double rank = 1.0 - double(outliers) / double(wave.size());
            return rank >= m_opts.threshold;
        }

        Collector& collector(int channel)
        {
            int group = 0;
            if (auto it = m_opts.chgrp.find(channel); it != m_opts.chgrp.end()) group = it->second;
            auto it = m_gcol.find(group);
            if (it == m_gcol.end()) it = m_gcol.emplace(group, Collector(m_dft, m_nfft)).first;
            return it->second;
        }

        CollectorOptions m_opts;
        WireCell::IDFT::pointer m_dft;
        std::map<int, Collector> m_gcol;
        double m_tick{0};
        std::size_t m_nfft{0}, m_nhalfout{0};
    };

    void fold_step(SpectraCollector& acc, wcphlex::Frame const& frame) { acc.add(frame.ptr); }

    // No send(): Phlex 0.4.3 advertises a fold's product with the
    // ACCUMULATOR's type even when a send() overload makes it store another
    // type, so statically typed consumers could not match.  The (movable)
    // accumulator is therefore the product and consumers call result().

    // As the WCT noise-spectra file format (aux/docs/noise.org).
    Json::Value to_json(NoiseSpectra const& ns)
    {
        Json::Value jout = Json::arrayValue;
        for (auto const& gs : ns.groups) {
            Json::Value je = Json::objectValue;
            je["group"] = gs.group;
            je["period"] = gs.period;
            je["nsamples"] = gs.nsamples;
            Json::Value jf = Json::arrayValue, ja = Json::arrayValue;
            for (float f : gs.freqs) jf.append(f);
            for (float a : gs.amps) ja.append(a);
            je["freqs"] = jf;
            je["amps"] = ja;
            jout.append(je);
        }
        return jout;
    }

    std::map<int, int> load_groups(std::string const& fname)
    {
        std::map<int, int> chgrp;
        if (fname.empty()) return chgrp;
        auto jgroups = WireCell::Persist::load(fname);
        for (auto const& jg : jgroups) {
            const int gid = jg.isMember("group") ? jg["group"].asInt() : jg["groupID"].asInt();
            for (auto const& jch : jg["channels"]) chgrp[jch.asInt()] = gid;
        }
        return chgrp;
    }

}  // namespace xsj

ARROW_NTUPLE_FIELDS(xsj::GroupSpectrum, group, period, nsamples, nwaves, nfft, freqs, amps);

using namespace phlex;

PHLEX_REGISTER_ALGORITHMS(m, config)
{
    const auto creator = config.get<std::string>("input_creator");
    const auto layer = config.get<std::string>("input_layer", "event");
    const auto suffix = config.get<std::string>("input_suffix", "frame");
    const auto partition = config.get<std::string>("partition", "job");
    const auto output_file = config.get<std::string>("output_file", "");
    const auto table = config.get<std::string>("table", "noise_spectra");

    xsj::CollectorOptions opts{
        .tag = config.get<std::string>("tag", ""),
        .chgrp = xsj::load_groups(config.get<std::string>("groups", "")),
        .nfft = static_cast<std::size_t>(config.get<int>("nfft", 0)),
        .nhalfout = static_cast<std::size_t>(config.get<int>("nhalfout", 0)),
        .maxdev = config.get<double>("maxdev", 0.0),
        .threshold = config.get<double>("threshold", 0.9),
    };

    m.fold("xsj_noise_fold", &xsj::fold_step, concurrency::serial, partition, std::move(opts))
      .input_family(product_selector{.creator = creator,
                                     .layer = layer,
                                     .suffix = experimental::identifier{suffix}})
      .output_product_suffixes("spectra");

    const product_selector spectra{.creator = "xsj_noise_fold",
                                   .layer = partition,
                                   .suffix = experimental::identifier{"spectra"}};

    if (!output_file.empty()) {
        m.observe("xsj_noise_json",
                  [output_file](xsj::SpectraCollector const& acc) {
                      WireCell::Persist::dump(output_file, xsj::to_json(acc.result()), true);
                  })
          .input_family(spectra);
    }

    m.transform("xsj_noise_table",
                [table](xsj::SpectraCollector const& acc) {
                    const auto ns = acc.result();
                    arrow_ntuple::row_ntuple<xsj::GroupSpectrum> rows(table);
                    for (auto const& gs : ns.groups) rows.append(gs);
                    phlex_arrow::TableGroup tg;
                    tg.type = table;
                    tg.members[table] = rows.finish();
                    return tg;
                })
      .input_family(spectra)
      .output_product_suffixes(table);
}
