// xsj.jsonnet -- shared helpers for xerosere-jobs top-level job configs.
//
// Every job's top-level Jsonnet is a function whose top-level arguments (TLAs)
// are all STRINGS (xsj passes them with phlexed -A).  The common TLAs every job
// accepts are listed in docs/cli.md; `common(args)` turns them into typed values.

{
    // "0,1,2" -> ["0","1","2"]; "" -> [].
    split(s):: if s == "" then [] else [std.stripChars(x, " ") for x in std.split(s, ",")],

    // "1,2.5" -> [1, 2.5]
    numbers(s):: [std.parseJson(x) for x in self.split(s)],

    // Parse a string TLA that may be empty into a number, else the default.
    number(s, default):: if s == "" then default else std.parseJson(s),

    // A Jsonnet array literal of numbers given as a string, e.g. "[-1000,2000,1000]".
    vector(s, default):: if s == "" then default else std.parseJson(s),

    truthy(s):: std.member(["1", "yes", "true", "on"], std.asciiLower(s)),

    // Normalize the common TLAs (see docs/cli.md).
    common(detector, variant, anodes, log_level, log_sink, output, nevents, seed):: {
        detector: detector,
        variant: variant,
        anodes: $.split(anodes),
        output: output,
        nevents: nevents,
        seed: seed,
        // Passed to every WCT island; wire-cell-phlex uses the level only
        // when a sink is given, so default the sink to stderr when a level is.
        log: {
            [if log_sink != "" || log_level != "" then "wct_log_sink"]:
                if log_sink == "" then "stderr" else log_sink,
            [if log_level != "" then "wct_log_level"]: log_level,
        },
    },

    // The standard driver: one "event" layer under "job".
    driver(nevents, layer="event"):: {
        cpp: "generate_layers",
        layers: { [layer]: { parent: "job", total: nevents, starting_number: 0 } },
    },

    // A wire-cell-phlex shape-executor island.
    //   cpp      : wcph_* module, e.g. "wcph_deposet_to_frame"
    //   inputs   : [{creator, layer, suffix}]
    //   suffix   : output product suffix
    //   config   : WCT job config file (on WIRECELL_PATH)
    //   plugins  : WCT plugin libraries
    //   tla      : extra WCT TLAs (strings)
    //   log      : the "log" object from common()
    island(cpp, inputs, suffix, config, plugins, tla={}, log={}):: {
        cpp: cpp,
        inputs: inputs,
        outputs: [{ suffix: suffix }],
        wct_config: config,
        wct_plugins: plugins,
        wct_tla: tla,
    } + log,

    // An input-spec element.
    input(creator, suffix, layer="event"):: { creator: creator, layer: layer, suffix: suffix },

    // Arrow tap of one WCT product, for persistence by hdf_output().
    tap(creator, types, layer="event"):: {
        cpp: "wire_cell_phlex_arrow_convert",
        input_layer: layer,
        input_creator: creator,
        types: types,
    },

    // Write every Arrow product to one HDF5 file (see docs/output.md).
    hdf_output(file):: {
        cpp: "phlex_arrow_hdf_output",
        output_file: file,
    },
}
