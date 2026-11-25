---
title: Using the standard jobs
viewpoint: user
status: draft
tracks:
  - at: c4c70f0a66
    paths: [python/src/xsj/cli.py, python/src/xsj/jobs]
---

# Using the standard jobs

By the end of this page you have run a job with `xsj` and found its output.

You need [an environment](xdoc:xerosere-docs/docs/admin/environment.md).

## See what there is

```sh
xsj list
```

```text
spdir      Signal-processing direction (SPDIR): ideal lines -> sim+SP and splat frames.
noise      Noise spectra: measure them (WCT noise-sim file format) or roundtrip them.
```

Each job describes itself and its options:

```sh
xsj noise -h
```

## Run one

Every job runs with no options.  It then uses its own defaults: a detector
(`pdhd`), a number of events, and an output file named after the job in the
current directory.

```sh
mkdir -p $XEROSERE_WORK/noise
cd $XEROSERE_WORK/noise
xsj noise
```

The log ends with the data layers Phlex met and what the run cost:

```text
Seen layers:

  job
   │
   └ event: 10
```

and the directory holds the output:

```text
noise.h5  noise.json.bz2
```

## Say what you want

The same options mean the same thing in every job.

```sh
xsj noise -d pdvd -N 4 -s 7 -o pdvd.h5
```

runs on the `pdvd` detector for 4 events with random seed 7 and writes
`pdvd.h5`.  The options most used:

| option | meaning |
|---|---|
| `-d` | detector |
| `-N` | number of events |
| `-o` | output file |
| `-L warn` | log only warnings and errors |
| `-j 4` | use at most 4 threads |
| `-A NAME=VALUE` | set any parameter of the job's configuration |
| `-n` | print the command that would run, and do not run it |

All of them are in [the command line](cli.md).

## Next

- What is in the file: [the output file](output.md).
- The jobs:

| job | purpose | page |
|---|---|---|
| `spdir` | signal-processing quality against track direction | [spdir](jobs/spdir.md) |
| `noise` | measure noise spectra, and check them through the noise simulation | [noise](jobs/noise.md) |
