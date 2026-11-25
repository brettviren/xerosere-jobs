---
title: The spdir job
viewpoint: user
status: draft
tracks:
  - at: c78c5b9f82
    paths: [cfg/xsj/jobs/spdir.jsonnet, python/src/xsj/jobs/spdir.py]
---

# The spdir job

`spdir` measures how well signal processing recovers charge as a function of
track direction.  It makes ideal straight tracks at a set of angles and, for
each, the signal a perfect detector would give and the signal after
simulation and signal processing.  By the end of this page you have made
both for a few angles.

You need [an environment](xdoc:xerosere-docs/docs/admin/environment.md), and
to have [run a job](../user.md).

## Run it

```sh
mkdir -p $XEROSERE_WORK/spdir
cd $XEROSERE_WORK/spdir
xsj spdir
```

This makes 10 events on anode 0 of `pdhd`, one for each track angle, and
writes `spdir.h5`.  Allow about a minute and 600 MB.

A quicker run, with three angles and without imaging:

```sh
xsj spdir -d pdvd --theta-xz 0,45,85 --no-imaging -o pdvd.h5
```

To try the job with little output on the terminal, on a few threads:

```sh
xsj spdir -N 2 -L warn -j 4 -o few.h5
```

`-N 2` keeps the first two angles.

## Options

Beyond [the common ones](../cli.md):

| option | meaning |
|---|---|
| `--theta-xz LIST` | The angles of the track in the X-Z plane, in degrees, from the Z axis toward X, the drift direction: 0 is across the drift, 90 along it.  One event each.  Default `0,5,30,45,60,75,80,85,87,89`. |
| `--theta-y LIST` | The angle of the track from the Y axis, in degrees: one value, or one for each `--theta-xz`.  Default `90`. |
| `--center '[x,y,z]'` | The middle of the track, in mm.  Default: a point in front of anode 0 of the detector. |
| `--length MM` | The length of the track.  Default `500`. |
| `--imaging`, `--no-imaging` | Also make charged blobs from the two signals.  Default: on. |

The kind of signal processing is a parameter of the job, not an option:
`-A sp=osp`.  `osp` is the only kind available.

## Output

There is one event for each angle:

```sh
h5ls spdir.h5/event
```

```text
0                        Group
1                        Group
...
9                        Group
```

and in each event one group for each product kept:

```sh
h5ls spdir.h5/event/1/CURRENT
```

```text
a_drifted                Group
a_img_sp                 Group
a_img_splat              Group
a_sampled                Group
a_segs                   Group
a_simsp                  Group
a_splat                  Group
lines                    Group
```

| group | what it holds |
|---|---|
| `lines` | The ideal track, as energy-deposit segments. |
| `a_segs`, `a_sampled`, `a_drifted` | The track as segments, as ionization deposits, and as deposits drifted to the anode. |
| `a_simsp` | The frame after simulation and signal processing. |
| `a_splat` | The frame a perfect detector would give. |
| `a_img_sp`, `a_img_splat` | Charged blobs made from each frame.  Absent with `--no-imaging`. |

How to read a frame is in [the output file](../output.md).

## Check the result

*To do: the comparison of `a_simsp` with `a_splat` by angle, and what a
correct result looks like.*
