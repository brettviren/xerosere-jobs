// noise.jsonnet -- the "noise" standard job: measure per-channel-group noise
// spectra, in the file format WCT's noise simulation reads.
//
// mode "roundtrip" (port of WCT gen/test/test-noise-roundtrip.jsonnet):
//   wcph_frame_gen (one empty frame per event)
//     -> WCT island xsj/wct/noise-sim.jsonnet: noise from a spectra file,
//        digitized and undigitized                           [noisy, voltage]
//     -> xsj_noise_spectra fold over all events -> spectra (job layer)
//        -> WCT noise file (spectra_file) and an HDF5 table
//   Compare the output spectra with the input file.
//
// mode "measure":
//   wcph_frame_source (WCT frame file of raw ADC, TLA input)
//     -> WCT island xsj/wct/noise-undigitize.jsonnet         [voltage]
//        (the signal veto, beads xero-653.4.1, will go here)
//     -> xsj_noise_spectra fold -> spectra, as above
//
// All TLAs are strings (docs/cli.md).

local xsj = import "xsj/lib/xsj.jsonnet";

function(
    // --- common TLAs ---
    detector = "pdhd",
    variant = "",
    anodes = "0",
    log_level = "",
    log_sink = "",
    output = "noise.h5",
    nevents = "",
    seed = "1",
    input = "",            // measure: WCT frame file (raw ADC)
    // --- noise TLAs ---
    mode = "roundtrip",    // roundtrip | measure
    noise_file = "",       // roundtrip: input spectra; "" = the detector's
    spectra_file = "",     // output WCT noise file; "" = <output> with .json.bz2
    groups = "",           // WCT channel-groups file; "" = one group
    nfft = "",             // collection size; "" = waveform length
    nhalfout = "",         // output half-spectrum size; "" = ceil(sqrt(nfft))
    maxdev = "",           // NoiseRanker maxdev (volts); "" = take every trace
    digitize = "yes",      // roundtrip: pass the noise through ADC and back
)
    local c = xsj.common(detector, variant, anodes, log_level, log_sink, output, nevents, seed);
    local ai = if std.length(c.anodes) > 0 then c.anodes[0] else "0";
    local nev = xsj.number(nevents, if mode == "roundtrip" then 10 else 1);
    local outspec = if spectra_file != "" then spectra_file
                    else (if std.endsWith(output, ".h5") then std.substr(output, 0, std.length(output) - 3)
                          else output) + ".json.bz2";
    local wct = { detector: detector, anode_index: ai };
    local plugins = ["WireCellGen", "WireCellSigProc", "WireCellAux", "WireCellPgraph"];

    local front =
        if mode == "roundtrip" then {
            sources: {
                trigger: { cpp: "wcph_frame_gen", output_layer: "event", output_suffix: "trigger" },
            },
            modules: {
                voltage: xsj.island("wcph_frame_filter",
                                    [xsj.input("input", "trigger")], "frame",
                                    "xsj/wct/noise-sim.jsonnet", plugins,
                                    wct { noise_file: noise_file, seed: seed, digitize: digitize },
                                    c.log),
            },
        } else if mode == "measure" then {
            sources: {
                raw: {
                    cpp: "wcph_frame_source",
                    output_layer: "event",
                    output_suffix: "raw",
                    wct_config: "frame-file-source.jsonnet",
                    wct_plugins: ["WireCellSio", "WireCellAux", "WireCellPgraph"],
                    wct_tla: { inname: if input == "" then error "noise: mode=measure needs input" else input },
                },
            },
            modules: {
                voltage: xsj.island("wcph_frame_filter",
                                    [xsj.input("input", "raw")], "frame",
                                    "xsj/wct/noise-undigitize.jsonnet",
                                    ["WireCellSigProc", "WireCellAux", "WireCellPgraph"],
                                    wct, c.log),
            },
        } else error "noise: unknown mode '%s' (roundtrip, measure)" % mode;

    {
        stage: "noise",
        driver: xsj.driver(nev),
        sources: front.sources,
        modules: front.modules + {
            spectra: {
                cpp: "xsj_noise_spectra",
                input_creator: "voltage",
                input_layer: "event",
                input_suffix: "frame",
                partition: "job",
                output_file: outspec,
            } + (if groups == "" then {} else { groups: groups })
              + (if nfft == "" then {} else { nfft: std.parseInt(nfft) })
              + (if nhalfout == "" then {} else { nhalfout: std.parseInt(nhalfout) })
              + (if maxdev == "" then {} else { maxdev: std.parseJson(maxdev) }),
            hdf_out: xsj.hdf_output(c.output),
        },
    }
