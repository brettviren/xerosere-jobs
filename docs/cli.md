---
title: The command line of the standard jobs
viewpoint: user
status: draft
tracks:
  - at: c78c5b9f82
    paths: [python/src/xsj/cli.py, python/src/xsj/runner.py, cfg/xsj/lib/xsj.jsonnet]
---

# The command line of the standard jobs

Every standard job runs through one entry point, `xsj`, a Python (Click)
wrapper around `phlexed`:

```
xsj JOB [COMMON OPTIONS] [JOB OPTIONS]
xsj list
```

`xsj` turns its options into Jsonnet top-level arguments (TLAs) of the job's
top-level configuration `cfg/xsj/jobs/JOB.jsonnet`, sets up the environment
and runs `phlexed -c JOB.jsonnet -A name=value ...`.  The configuration is
also usable without `xsj`: run `phlexed` directly with the same TLAs (the
ctest smoke tests do).

## Common options

| option | TLA | meaning |
|---|---|---|
| `-d/--detector` | `detector` | dune-config detector name: `pdhd pdsp pdvd fdhd fdvd`.  Guessed from the input file name when not given (`np04hd*` pdhd, `np04*` pdsp, `np02vd*` pdvd), else the job's default. |
| `-V/--variant` | `variant` | detector variant, eg fdhd `ideal`, `1x2x6`, `1x2x2`. |
| `-a/--anodes` | `anodes` | comma-separated anode indices. |
| `-i/--input` | `input` | input file, for jobs that read one (made absolute). |
| `-o/--output` | `output` | output HDF5 file, default `JOB.h5` (made absolute; see output.md). |
| `-N/--nevents` | `nevents` | number of events; default is the job's natural number. |
| `-s/--seed` | `seed` | random seed. |
| `-L/--log-level` | `log_level` | `trace debug info warn error critical off`, for Phlex (as `SPDLOG_LEVEL`) and WCT. |
| `-l/--log-sink` | `log_sink` | WCT log sink: `stdout`, `stderr` or a file.  Phlex logs to the terminal. |
| `-j/--threads` | (phlexed `-j`) | maximum Phlex parallelism. |
| `-A/--tla NAME=VALUE` | any | set any TLA the job accepts (repeatable). |
| `-c/--config FILE` | | run this top-level Jsonnet instead of the job's. |
| `-n/--dry-run` | | print the environment and the `phlexed` command; do not run. |

`-n` keeps its dune-config scripts meaning (dry run); the event count is `-N`.

Options for details that only some jobs have are TLAs, not common option
names.  In particular the signal-processing flavor is the TLA `sp`
(`-A sp=osp` or `-A sp=spng`), taken by jobs that run signal processing.

## Job options

Each job adds its own options, each mapping one-to-one onto a TLA of its
Jsonnet (see `xsj JOB -h`).  `xsj` refuses a TLA the job does not declare.

## Top-level Jsonnet interface

A job's top-level Jsonnet is a function of string TLAs only (`phlexed -A`).
Every job accepts the common TLAs with these names and defaults:

```jsonnet
function(detector="<job default>", variant="", anodes="0",
         log_level="", log_sink="", output="<job>.h5", nevents="", seed="",
         /* job TLAs */ ...)
```

and normalizes them with `xsj.common(...)` from `cfg/xsj/lib/xsj.jsonnet`.
Jobs that read input add `input`.  Jobs with signal processing add `sp`.

## Environment

`xsj` expects an activated build environment (eg `xero shell -t xerosere`)
with `phlexed` on `PATH` and detector data (wire-cell-data) on
`WIRECELL_PATH`.  From the install prefix (`XSJ_PREFIX`, else the prefix of
`phlexed`) it adds:

- `PHLEXED_PATH`: `share/xerosere-jobs/cfg` (`XSJ_CFG` overrides).
- `PHLEX_PLUGIN_PATH`: `lib`, `lib64`, and the `lib` next to `phlex` (for
  `generate_layers`).
- `WIRECELL_PATH`: `share/wire-cell-phlex/cfg` and `share/wirecell`.
- `GODEBUG=asyncpreemptoff=1`: needed when several WCT islands per event
  run the embedded go-jsonnet.

## Exit codes

0 pass, 1 failure, 77 skipped (a prerequisite is missing).
