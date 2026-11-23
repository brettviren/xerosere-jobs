// xsj/wct/noise-undigitize.jsonnet -- WCT island (IFrame -> IFrame): convert
// raw ADC frames to voltage for noise measurement.
//
//   FrameBoundarySource -> Undigitizer -> FrameBoundarySink
//
// The signal veto (beads xero-653.4.1) will go between Undigitizer and the sink.
//
// TLAs (strings): sources, sinks, app_name; detector, anode_index, service_prefix.
// Required WCT plugins: WireCellPgraph, WireCellSigProc, WireCellAux

local wc = import "wirecell.jsonnet";
local dets = import "dune/wct/dets.jsonnet";

function(
    sources = [],
    sinks = [],
    app_name = "wcphlex_pgrapher",
    detector = "pdhd",
    anode_index = "0",
    service_prefix = "",
)
    local det = dets[detector]({ detname: detector });
    local a = det.anodes[std.parseInt(anode_index)];
    local pre = service_prefix + "undig_";
    local wires = { type: "WireSchemaFile", name: pre + "wires_" + a.name,
                    data: { filename: det.wires.filename } };
    local anode = {
        type: "AnodePlane",
        name: pre + a.name,
        data: { ident: a.ident, nimpacts: det.sim.nimpacts,
                wire_schema: wc.tn(wires), faces: a.faces },
    };
    local undigitizer = {
        type: "Undigitizer",
        name: pre + a.name,
        data: {
            anode: wc.tn(anode),
            resolution: a.adc.resolution,
            gain: a.adc.gain,
            fullscale: a.adc.fullscale,
            baselines: a.adc.baselines,
        },
    };
    local src = sources[0] { data: {} };
    local snk = sinks[0] { data: {} };
    [wires, anode, src, undigitizer, snk, {
        type: "Pgrapher",
        name: app_name,
        data: { edges: [
            { tail: { node: wc.tn(src), port: 0 }, head: { node: wc.tn(undigitizer), port: 0 } },
            { tail: { node: wc.tn(undigitizer), port: 0 }, head: { node: wc.tn(snk), port: 0 } },
        ] },
    }]
