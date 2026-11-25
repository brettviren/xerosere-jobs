---
title: Design of xerosere-jobs
viewpoint: design
status: placeholder
tracks:
  - at: 2890da0c21
    paths: [src/noise_spectra.cpp, cfg/xsj/lib, python/src/xsj]
---

# Design of xerosere-jobs

How a standard job is put together: a Python command, a Jsonnet
configuration and a Phlex workflow.

*Placeholder.  Sections to write: purpose, the three layers (`xsj`, the
job's Jsonnet, Phlex modules and Wire-Cell islands), decisions, limits.*

## Accumulating over events

A result made from all events, such as the noise spectra, is a Phlex fold.
The step adds one frame to the accumulator:

<!-- xdoc:snippet xerosere-jobs:src/noise_spectra.cpp anchor=fold-step -->
```cpp
void fold_step(SpectraCollector& acc, wcphlex::Frame const& frame) { acc.add(frame.ptr); }
```
<!-- xdoc:end -->

It is registered with the layer whose end produces the result:

<!-- xdoc:snippet xerosere-jobs:src/noise_spectra.cpp anchor=fold-register -->
```cpp
m.fold("xsj_noise_fold", &xsj::fold_step, concurrency::serial, partition, std::move(opts))
  .input_family(product_selector{.creator = creator,
                                 .layer = layer,
                                 .suffix = experimental::identifier{suffix}})
  .output_product_suffixes("spectra");
```
<!-- xdoc:end -->
