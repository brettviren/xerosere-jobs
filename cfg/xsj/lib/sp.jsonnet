// sp.jsonnet -- signal-processing flavors for sim+sigproc islands.
//
// The SP flavor is a TLA ("sp"), not a CLI option: it only matters to jobs
// that run signal processing.  Selecting it changes the island's WCT config
// and plugins; the rest of a job graph is unchanged.
{
    osp: {
        config: "dune/wct/job/sim-sigproc.jsonnet",
        plugins: ["WireCellGen", "WireCellSigProc", "WireCellAux", "WireCellPgraph"],
    },
    // Not available yet: needs a sim+SPNG island config (beads xero-653.1.11).
    spng: {
        config: "dune/wct/job/sim-spng.jsonnet",
        plugins: ["WireCellGen", "WireCellSigProc", "WireCellSpng", "WireCellAux", "WireCellPgraph"],
    },

    get(name):: if std.objectHas(self, name) then self[name]
                else error "unknown sp flavor '%s' (known: osp, spng)" % name,
}
