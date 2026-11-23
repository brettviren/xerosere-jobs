# Output convention

A job writes one HDF5 file (`-o/--output`, default `JOB.h5`) with
`phlex_arrow_hdf_output`.  Every product worth keeping is converted to Arrow
by a tap module (`xsj.tap(creator, types)`, ie `wire_cell_phlex_arrow_convert`)
or is already an Arrow product (eg `edp_line_gen`'s `edep.observables`).

Paths follow the phlex-arrow address scheme:

```
/event/<n>/CURRENT/<tap-module>/<converter>/<product>/<table>/<column>
```

for example, in `spdir.h5`:

| product | path |
|---|---|
| sim+SP frame | `/event/<n>/CURRENT/a_simsp/wc_frame_to_arrow/frame/traces/...` |
| splat frame | `/event/<n>/CURRENT/a_splat/wc_frame_to_arrow/frame/traces/...` |
| drifted depos | `/event/<n>/CURRENT/a_drifted/.../deposet/deposet/...` |
| charged blobs | `/event/<n>/CURRENT/a_img_sp/.../cluster/blobs/...` |

Products made at the job layer (eg a fold over all events) have no
`/event/<n>` prefix, eg the noise job's spectra table:
`/CURRENT/spectra/xsj_noise_table/noise_spectra/noise_spectra/{group,period,nsamples,nwaves,nfft,freqs,amps}`
(list columns `freqs`, `amps` with `.__offsets__`).

Conventions:

- Tap modules are named `a_<creator>`.
- Job-level results (fits, metrics, spectra) are arrow-ntuple tables made by
  a phlex-ntuple fold and written by the same output module into the same file.

To do (beads xero-653.1.7): record job metadata (detector, variant, job
version, TLAs) in the file.
