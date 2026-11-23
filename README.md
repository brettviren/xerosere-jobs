# xerosere-jobs

Standard DUNE jobs built on Phlex and the Wire-Cell Toolkit, each run through
one command-line entry point, `xsj`, with a common set of options.

| job | what it does |
|---|---|
| `spdir` | signal-processing direction metrics: ideal lines -> sim+SP and splat frames (and charged blobs) |
| `morse` | (planned) measure SP smearing for DepoFluxSplat |
| `noise` | measure noise spectra (WCT noise-sim file format) and roundtrip them through the noise simulation (signal veto still to come) |

```
xsj list
xsj spdir -d pdhd -N 3 -o spdir.h5
xsj spdir -d pdvd -A sp=osp --no-imaging --theta-xz 0,45,85
xsj noise -d pdhd -N 10 -o rt.h5   # roundtrip: rt.json.bz2 + rt.h5
xsj spdir -n ...          # print the phlexed command
```

Layout:

- `cfg/xsj/jobs/JOB.jsonnet`: each job's top-level Phlex configuration, a
  function of string TLAs (installed to `share/xerosere-jobs/cfg`).
- `cfg/xsj/lib/`: shared Jsonnet (common TLAs, WCT islands, Arrow taps, HDF5
  output, SP flavors).
- `python/`: the `xsj` package.
- `docs/cli.md`: the command-line convention; `docs/output.md`: the output file.
- `test/`: ctest smoke tests (run the Jsonnet through `phlexed`).

Building: as part of a xero superbuild (`xero build -t xerosere`), or
standalone with CMake.  Install `python/` into a venv for `xsj`
(`uv pip install -e python`).
