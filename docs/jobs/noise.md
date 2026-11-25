---
title: The noise job
viewpoint: user
status: draft
tracks:
  - at: c78c5b9f82
    paths: [cfg/xsj/jobs/noise.jsonnet, python/src/xsj/jobs/noise.py, cfg/xsj/wct]
---

# The noise job

`noise` measures the mean noise amplitude spectrum of each group of channels
and writes it in the file format the Wire-Cell noise simulation reads.  By
the end of this page you have made such a file from simulated noise.

You need [an environment](xdoc:xerosere-docs/docs/admin/environment.md), and
to have [run a job](../user.md).

The job has two modes.  `roundtrip`, the default, simulates noise from a
known spectrum, passes it through the ADC and back, and measures it.
`measure` measures the noise in recorded data.

## Run it

```sh
mkdir -p $XEROSERE_WORK/noise
cd $XEROSERE_WORK/noise
xsj noise
```

This simulates 10 events of noise on anode 0 of `pdhd` and writes two files:

| file | what it is |
|---|---|
| `noise.json.bz2` | The measured spectra, as a Wire-Cell noise file. |
| `noise.h5` | The same spectra as a table, in [the output file](../output.md) of the job. |

Another detector, fewer events, another seed and another file name:

```sh
xsj noise -d pdvd -N 4 -s 7 -o pdvd.h5
```

This writes `pdvd.h5` and `pdvd.json.bz2`.  The noise file takes its name
from the output file unless `--spectra-file` names it.

## Options

Beyond [the common ones](../cli.md):

| option | meaning |
|---|---|
| `--mode roundtrip` or `measure` | What to do.  Default `roundtrip`. |
| `--noise-file FILE` | `roundtrip`: the spectra to simulate from.  Default: the detector's. |
| `--spectra-file FILE` | Where to write the Wire-Cell noise file. |
| `--groups FILE` | A Wire-Cell channel-groups file.  Default: all channels in one group. |
| `-i FILE` | `measure`: a Wire-Cell frame file of raw ADC. |

## Output

The table is one row for each channel group:

```sh
h5ls -r noise.h5
```

```text
/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/amps Dataset {78}
/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/freqs Dataset {78}
/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/group Dataset {1}
/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/nfft Dataset {1}
/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/nsamples Dataset {1}
/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/nwaves Dataset {1}
/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/period Dataset {1}
```

(The listing also shows the table's schema and the offsets of its list
columns.)

| column | meaning |
|---|---|
| `group` | The channel group. |
| `freqs`, `amps` | The spectrum: frequencies and mean amplitudes, in the Wire-Cell system of units. |
| `nwaves` | How many waveforms went into the mean. |
| `nsamples` | The length of each waveform, in ticks. |
| `nfft` | The size of the transform. |
| `period` | The sampling period. |

The spectra are made at the job layer, from all events, so the table has no
`/event/N` in its path.

## Check the result

`nwaves` is the number of channels times the number of events.  For the first
run above, anode 0 of `pdhd` has 2560 channels:

```sh
h5dump -d /CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/nwaves noise.h5
```

```text
   (0): 25600
```

*To do: compare the measured spectrum with the one simulated from.*

## Limits

- The file the job writes cannot yet be given back to it as `--noise-file`.
- `measure` has not been run on recorded data, and does not yet exclude
  signal from the waveforms.

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
