# xerosere-jobs: standard DUNE jobs on Phlex + the Wire-Cell Toolkit.
#
# Installs the job configurations (share/xerosere-jobs/cfg, put on PHLEXED_PATH
# by xsj), docs, and the pure-Phlex job algorithms (C++ Phlex plugins).  The
# xsj command-line entry point is the Python package in python/ (installed
# separately, eg into a venv).
cmake_minimum_required(VERSION 3.24)
project(xerosere_jobs VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(GNUInstallDirs)

# Build dependencies of the Phlex plugins.  phlexConfig does not find its own
# dependencies, so find them first (see notes on building against phlex).
find_package(Boost REQUIRED COMPONENTS json)
find_package(TBB REQUIRED)
find_package(spdlog REQUIRED)
find_package(fmt REQUIRED)
find_package(phlex 0.4.1 REQUIRED)
find_package(WireCell REQUIRED)
find_package(wire_cell_phlex REQUIRED)
find_package(Arrow CONFIG REQUIRED)
find_package(arrow_ntuple CONFIG REQUIRED)
find_package(phlex_arrow_common CONFIG REQUIRED)

# Runtime dependencies of the jobs, loaded as Phlex or WCT plugins.  Found
# QUIETly; naming them also orders this package after them in a xero superbuild.
foreach(_dep IN ITEMS
    phlexed
    wire_cell_phlex_arrow
    phlex_arrow_hdf
    phlex_ntuple
    edep_phlex
    dune_config
    phlex_gdml
    gdml_objects
    dune_daq_phlex)
  find_package(${_dep} QUIET)
  if(${_dep}_FOUND)
    message(STATUS "xerosere-jobs: found ${_dep}")
  else()
    message(STATUS "xerosere-jobs: ${_dep} not found (needed at run time by some jobs)")
  endif()
endforeach()

# --- Pure-Phlex job algorithms ----------------------------------------------
# noise: fold frames into per-channel-group noise spectra (WCT Aux Collector).
add_library(xsj_noise_spectra MODULE src/noise_spectra.cpp)
target_link_libraries(xsj_noise_spectra PRIVATE
  phlex::module
  wire_cell_phlex::wire_cell_phlex
  WireCell::Aux WireCell::Util WireCell::Iface
  arrow_ntuple::arrow_ntuple
  phlex_arrow_common::phlex_arrow_common)
install(TARGETS xsj_noise_spectra LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}")

install(DIRECTORY cfg/
  DESTINATION "${CMAKE_INSTALL_DATADIR}/xerosere-jobs/cfg"
  FILES_MATCHING PATTERN "*.jsonnet")
install(DIRECTORY docs/
  DESTINATION "${CMAKE_INSTALL_DATADIR}/xerosere-jobs/docs"
  FILES_MATCHING PATTERN "*.md")

include(CTest)
if(BUILD_TESTING)
  add_subdirectory(test)
endif()
