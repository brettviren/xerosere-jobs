# Smoke tests run the job Jsonnet straight through phlexed (no xsj, so no
# Python dependency at test time).  Exit code 77 = skipped.
set(_smoke "${CMAKE_CURRENT_SOURCE_DIR}/smoke.sh")
set(_cfg "${PROJECT_SOURCE_DIR}/cfg")

add_test(NAME spdir-pdhd-osp
  COMMAND ${_smoke} ${_cfg} spdir
          "/a_simsp/.*/frame/traces/wc.trace.charge Dataset"
          "/a_splat/.*/frame/traces/wc.trace.charge Dataset"
          "/a_drifted/.*/deposet/deposet/wc.depo.charge Dataset"
          -- detector=pdhd nevents=2 imaging=no)
add_test(NAME spdir-pdhd-imaging
  COMMAND ${_smoke} ${_cfg} spdir
          "/a_img_sp/.*/blobs/wc.blob.value Dataset"
          "/a_img_splat/.*/blobs/wc.blob.value Dataset"
          -- detector=pdhd nevents=1)
add_test(NAME noise-roundtrip-pdhd
  COMMAND ${_smoke} ${_cfg} noise
          "noise_spectra.*Dataset"
          -- detector=pdhd mode=roundtrip nevents=3)
set_tests_properties(spdir-pdhd-osp spdir-pdhd-imaging noise-roundtrip-pdhd
  PROPERTIES SKIP_RETURN_CODE 77)
