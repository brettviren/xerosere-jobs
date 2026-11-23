// xsj/wct/noise-sim.jsonnet -- WCT island (IFrame -> IFrame): simulate noise
// on an empty frame and return it as voltage, as WCT's
// gen/test/test-noise-roundtrip.jsonnet does ahead of NoiseModeler:
//
//   FrameBoundarySource -> Reframer (dense zeros, all anode channels)
//     -> AddNoise (EmpiricalNoiseModel) -> Digitizer -> Undigitizer
//     -> FrameBoundarySink
//
// The input frame is only a trigger (eg from wcph_frame_gen); its traces are
// ignored except as Reframer input.  Detector parameters come from the
// wire-cell-phlex detector configs (dune/wct/dets.jsonnet).
//
// TLAs (strings): sources, sinks, app_name (from the executor); detector,
// anode_index, service_prefix; noise_file ("" = the anode's configured
// spectra), seed, digitize ("yes": round trip through ADC; "no": voltage).
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellSigProc, WireCellAux

local wc = import "wirecell.jsonnet";
local dets = import "dune/wct/dets.jsonnet";

function(
    sources = [],
    sinks = [],
    app_name = "wcphlex_pgrapher",
    detector = "pdhd",
    anode_index = "0",
    service_prefix = "",
    noise_file = "",
    seed = "1",
    digitize = "yes",
)
    local det = dets[detector]({ detname: detector });
    local ai = std.parseInt(anode_index);
    local a = det.anodes[ai];
    local tick = det.daq.tick;
    local nticks = det.daq.nticks;
    local pre = service_prefix + "noise_";

    local dft = { type: "FftwDFT", name: pre + "dft_" + a.name, data: {} };
    local rng = { type: "Random", name: pre + "rng_" + a.name,
                  data: { seed: std.parseInt(seed) } };
    local wires = { type: "WireSchemaFile", name: pre + "wires_" + a.name,
                    data: { filename: det.wires.filename } };
    local anode = {
        type: "AnodePlane",
        name: pre + a.name,
        data: { ident: a.ident, nimpacts: det.sim.nimpacts,
                wire_schema: wc.tn(wires), faces: a.faces },
    };
    local reframer = {
        type: "Reframer",
        name: pre + "reframer_" + a.name,
        data: { anode: wc.tn(anode), tags: [], fill: 0.0, tbin: 0, toffset: 0, nticks: nticks },
    };
    local model = {
        type: "EmpiricalNoiseModel",
        name: pre + "model_" + a.name,
        data: {
            anode: wc.tn(anode),
            dft: wc.tn(dft),
            chanstat: "",
            spectra_file: if noise_file == "" then a.noise.filename else noise_file,
            nsamples: nticks,
            period: tick,
            wire_length_scale: a.noise.wire_length_scale,
        },
    };
    local addnoise = {
        type: "AddNoise",
        name: pre + "addnoise_" + a.name,
        data: { rng: wc.tn(rng), dft: wc.tn(dft), model: wc.tn(model),
                nsamples: nticks, replacement_percentage: 0.02 },
    };
    local adc = {
        anode: wc.tn(anode),
        resolution: a.adc.resolution,
        gain: a.adc.gain,
        fullscale: a.adc.fullscale,
        baselines: a.adc.baselines,
    };
    local digitizer = { type: "Digitizer", name: pre + "digitizer_" + a.name, data: adc };
    local undigitizer = { type: "Undigitizer", name: pre + "undigitizer_" + a.name, data: adc };

    local src = sources[0] { data: {} };
    local snk = sinks[0] { data: {} };

    local chain = [src, reframer, addnoise]
                  + (if digitize == "yes" then [digitizer, undigitizer] else [])
                  + [snk];
    local edges = [
        { tail: { node: wc.tn(chain[i]), port: 0 }, head: { node: wc.tn(chain[i + 1]), port: 0 } }
        for i in std.range(0, std.length(chain) - 2)
    ];

    [dft, rng, wires, anode, model] + chain + [
        { type: "Pgrapher", name: app_name, data: { edges: edges } },
    ]
