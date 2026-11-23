// spdir.jsonnet -- the "spdir" standard job: signal-processing direction metrics.
//
// Ported from ~/dune/xerosere/tests/spdir (spdir.jsonnet.in + run.sh).
//
//   edp_line_gen (source)                ideal line segments -> edep.observables
//     -> wire_cell_phlex_arrow_edep_segments    -> WCT TrackSegmentSet
//     -> wcph_tracksegmentset_to_deposet        sample depos (quanta)  [sampled]
//     -> wcph_deposet_filter                    one common drift       [drifted]
//         |-> wcph_deposet_to_frame   sim+sigproc (flavor: TLA sp)     [simsp]
//         |    `-> wcph_frame_to_cluster          imaging, solved q     [img_sp]
//         `-> wcph_deposet_to_frame   DepoFluxSplat "true" signal      [splat]
//              `-> wcph_frame_deposet_to_cluster imaging, true q       [img_splat]
//
// Every product is tapped to Arrow and written to one HDF5 file.  One event per
// line direction.  All TLAs are strings (see docs/cli.md); the job-specific
// ones are documented below.

local xsj = import "xsj/lib/xsj.jsonnet";
local sps = import "xsj/lib/sp.jsonnet";

local deg = 3.141592653589793 / 180.0;  // hep-units: angles are radians

// Per-detector defaults: the line center (mm) inside anode 0's drift volume and
// the BlobDepoFill time offset (ns) that aligns drifted-depo times with the
// splat frame (the field response origin/speed; see tests/spdir/run.sh).
local det_defaults = {
    pdhd: { center: [-1000.0, 2000.0, 1000.0], toffset: "63000" },
    pdvd: { center: [-1000.0, -1000.0, 745.0], toffset: "117000" },
    pdsp: { center: [-1000.0, 2000.0, 1000.0], toffset: "63000" },
};

function(
    // --- common TLAs (docs/cli.md) ---
    detector = "pdhd",
    variant = "",
    anodes = "0",
    log_level = "",
    log_sink = "",
    output = "spdir.h5",
    nevents = "",          // "" -> one event per direction
    seed = "",
    // --- spdir TLAs ---
    sp = "osp",            // signal-processing flavor: osp | spng
    imaging = "yes",       // also tile frames into charged 3D blobs
    center = "",           // "[x,y,z]" in mm; "" -> detector default
    length = "500",        // line length, mm
    density = "",          // electrons/mm; "" -> generator default (5000/mm)
    theta_y = "90",        // degrees; one value, or one per theta_xz
    theta_xz = "0,5,30,45,60,75,80,85,87,89",  // degrees
    toffset = "",          // BlobDepoFill time offset, ns; "" -> detector default
)
    local c = xsj.common(detector, variant, anodes, log_level, log_sink, output, nevents, seed);
    local dd = if std.objectHas(det_defaults, detector) then det_defaults[detector]
               else error "spdir: no defaults for detector '%s' (known: %s)"
                          % [detector, std.join(", ", std.objectFields(det_defaults))];
    local spd = sps.get(sp);
    local ai = if std.length(c.anodes) > 0 then c.anodes[0] else "0";
    local txz = xsj.numbers(theta_xz);
    local ty0 = xsj.numbers(theta_y);
    local ty = if std.length(ty0) == 1 then [ty0[0] for t in txz] else ty0;
    assert std.length(ty) == std.length(txz) : "spdir: theta_y and theta_xz lengths differ";
    local ndirs = std.length(txz);
    local nev = xsj.number(nevents, ndirs);
    assert nev <= ndirs : "spdir: nevents (%d) exceeds the number of directions (%d)" % [nev, ndirs];
    local do_img = xsj.truthy(imaging);
    local wct = { detector: detector, anode_index: ai };
    local inp = xsj.input;

    {
        stage: "spdir",
        driver: xsj.driver(nev),

        sources: {
            lines: {
                cpp: "edp_line_gen",
                output_layer: "event",
                center: xsj.vector(center, dd.center),
                length: xsj.number(length, 500.0),
                theta_y: [t * deg for t in ty],
                theta_xz: [t * deg for t in txz],
                coords: "global",
            } + (if density == "" then {} else { density: xsj.number(density, 0) }),
        },

        modules: {
            segs: {
                cpp: "wire_cell_phlex_arrow_edep_segments",
                input_layer: "event",
                input_creator: "input",
                input_suffix: "observables",
            },
            sampler: xsj.island("wcph_tracksegmentset_to_deposet",
                                [inp("segs", "tracksegmentset")], "deposet",
                                "tracksegmentset-sampler.jsonnet",
                                ["WireCellGen", "WireCellPgraph"],
                                { ionization: "quanta" }, c.log),
            drift: xsj.island("wcph_deposet_filter",
                              [inp("sampler", "deposet")], "deposet",
                              "dune/wct/job/drift.jsonnet",
                              ["WireCellGen", "WireCellAux", "WireCellPgraph"],
                              wct { input: "deposet" }, c.log),
            simsp: xsj.island("wcph_deposet_to_frame",
                              [inp("drift", "deposet")], "frame",
                              spd.config, spd.plugins,
                              wct { input: "drifted" }, c.log),
            // FieldResponse (DepoFluxSplat origin/speed) is in WireCellSigProc.
            splat: xsj.island("wcph_deposet_to_frame",
                              [inp("drift", "deposet")], "frame",
                              "dune/wct/job/splat.jsonnet",
                              ["WireCellGen", "WireCellSigProc", "WireCellAux", "WireCellPgraph"],
                              wct { input: "drifted" }, c.log),

            a_segs: xsj.tap("segs", ["tracksegmentset"]),
            a_sampled: xsj.tap("sampler", ["deposet"]),
            a_drifted: xsj.tap("drift", ["deposet"]),
            a_simsp: xsj.tap("simsp", ["frame"]),
            a_splat: xsj.tap("splat", ["frame"]),

            hdf_out: xsj.hdf_output(c.output),
        } + (if !do_img then {} else {
            // Distinct service_prefix per imaging island: both use img.jsonnet
            // and WCT's NamedFactory is a singleton per (type, name).
            img_sp: xsj.island("wcph_frame_to_cluster",
                               [inp("simsp", "frame")], "cluster",
                               "dune/wct/job/img.jsonnet",
                               ["WireCellGen", "WireCellImg", "WireCellAux", "WireCellPgraph"],
                               wct { slicer: "sum", sum_tag: "gauss", charge: "solve",
                                     service_prefix: "imgsp_" }, c.log),
            img_splat: xsj.island("wcph_frame_deposet_to_cluster",
                                  [inp("splat", "frame"), inp("drift", "deposet")], "cluster",
                                  "dune/wct/job/img.jsonnet",
                                  ["WireCellGen", "WireCellImg", "WireCellAux", "WireCellPgraph"],
                                  wct { slicer: "sum", charge: "depofill",
                                        depofill_time_offset: if toffset == "" then dd.toffset else toffset,
                                        service_prefix: "imgsplat_" }, c.log),
            a_img_sp: xsj.tap("img_sp", ["cluster"]),
            a_img_splat: xsj.tap("img_splat", ["cluster"]),
        }),
    }
