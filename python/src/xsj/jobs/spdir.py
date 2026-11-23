"""The spdir job: signal-processing direction metrics."""

from ..cli import COMMON_TLAS, Job, opt

job = Job(
    "spdir",
    help="""Signal-processing direction (SPDIR): ideal lines -> sim+SP and splat frames.

    One event per line direction (theta_y, theta_xz).  Writes the segments,
    sampled and drifted depos, the sim+SP and splat frames and (with imaging)
    their charged blobs to one HDF5 file.  Analyze it with 'wct-metrics spdir'.
    The SP flavor is the TLA 'sp' (-A sp=osp|spng).
    """,
    tlas=COMMON_TLAS + ["sp", "imaging", "center", "length", "density",
                        "theta_y", "theta_xz", "toffset"],
    options=[
        opt("--theta-xz", tla="theta_xz", default=None,
            help="Comma-separated theta_xz angles, degrees."),
        opt("--theta-y", tla="theta_y", default=None,
            help="theta_y degrees: one value or one per theta_xz."),
        opt("--center", tla="center", default=None,
            help="Line center '[x,y,z]' in mm. Default: per detector."),
        opt("--length", tla="length", default=None, help="Line length, mm."),
        opt("--imaging/--no-imaging", tla="imaging", default=None,
            help="Tile the frames into charged 3D blobs (default: on)."),
    ],
)
