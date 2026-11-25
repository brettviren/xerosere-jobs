---
title: The noise job
view: user
status: placeholder
tracks:
  - at: c78c5b9f82
    paths: [cfg/xsj/jobs/noise.jsonnet, python/src/xsj/jobs/noise.py, cfg/xsj/wct]
---

# The noise job

`noise` measures the mean noise amplitude spectrum of each group of channels
and writes it in the file format the Wire-Cell noise simulation reads.

*Placeholder.  Sections to write: run it, options, output, check the
result.*

## Change it

The job's configuration takes these parameters.  `xsj noise -A NAME=VALUE`
sets any of them.

<!-- xdoc:snippet xerosere-jobs:cfg/xsj/jobs/noise.jsonnet from="^function\(" to="^\)" -->
```jsonnet
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
```
<!-- xdoc:end -->
