"""The noise job: measure noise spectra and roundtrip them."""

import click

from ..cli import COMMON_TLAS, Job, opt

job = Job(
    "noise",
    help="""Noise spectra: measure them (WCT noise-sim file format) or roundtrip them.

    --mode roundtrip: simulate noise from a spectra file (--noise-file, default
    the detector's), digitize and undigitize it, and measure the spectra again.
    --mode measure: measure the spectra of raw ADC frames (-i, a WCT frame file).
    Writes the spectra as a WCT noise file (--spectra-file, default <output>
    with .json.bz2) and as a table in the HDF5 output.
    """,
    tlas=COMMON_TLAS + ["input", "mode", "noise_file", "spectra_file", "groups",
                        "nfft", "nhalfout", "maxdev", "digitize"],
    options=[
        opt("--mode", tla="mode", default=None,
            type=click.Choice(["roundtrip", "measure"]),
            help="roundtrip (default) or measure."),
        opt("--noise-file", tla="noise_file", default=None,
            help="roundtrip: input noise spectra file. Default: the detector's."),
        opt("--spectra-file", tla="spectra_file", default=None,
            help="Output WCT noise spectra file (.json or .json.bz2)."),
        opt("--groups", tla="groups", default=None,
            help="WCT channel-groups file. Default: one group."),
    ],
)
