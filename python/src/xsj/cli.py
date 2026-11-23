"""xsj: the command-line entry point for xerosere-jobs standard jobs.

    xsj [JOB] [COMMON OPTIONS] [JOB OPTIONS]

Common options are the same for every job (docs/cli.md).  Each job's options
map one-to-one onto TLAs of its top-level Jsonnet (cfg/xsj/jobs/<job>.jsonnet).
"""

import functools
import re
import sys
from pathlib import Path

import click

from . import runner

CONTEXT = dict(help_option_names=["-h", "--help"], max_content_width=100)

LOG_LEVELS = ["trace", "debug", "info", "warn", "error", "critical", "off"]

# Detector guessed from an input file name when -d/--detector is not given.
DETECTOR_GUESS = [
    (re.compile(r"np04hd"), "pdhd"),
    (re.compile(r"np04"), "pdsp"),
    (re.compile(r"np02vd"), "pdvd"),
]


def guess_detector(path: str) -> str | None:
    name = Path(path).name
    for pat, det in DETECTOR_GUESS:
        if pat.search(name):
            return det
    return None


def common_options(f):
    """The options every job accepts (docs/cli.md)."""
    opts = [
        click.option("-d", "--detector", default=None,
                     help="Detector: pdhd, pdsp, pdvd, fdhd, fdvd. Default: guessed from "
                     "the input name, else the job's default."),
        click.option("-V", "--variant", default=None,
                     help="Detector variant, e.g. fdhd 'ideal', '1x2x6'."),
        click.option("-a", "--anodes", default=None,
                     help="Comma-separated anode indices."),
        click.option("-i", "--input", "input_", default=None, type=click.Path(),
                     help="Input file (jobs that read one)."),
        click.option("-o", "--output", default=None, type=click.Path(),
                     help="Output HDF5 file. Default: <job>.h5 in the current directory."),
        click.option("-N", "--nevents", default=None, type=int,
                     help="Number of events. Default: the job's natural number."),
        click.option("-s", "--seed", default=None, type=int, help="Random seed."),
        click.option("-L", "--log-level", default=None, type=click.Choice(LOG_LEVELS),
                     help="Log level for Phlex and WCT."),
        click.option("-l", "--log-sink", default=None,
                     help="WCT log sink: stdout, stderr or a file name."),
        click.option("-j", "--threads", default=None, type=int,
                     help="Maximum Phlex parallelism."),
        click.option("-A", "--tla", "tlas", multiple=True, metavar="NAME=VALUE",
                     help="Set any job TLA (repeatable); e.g. -A sp=spng."),
        click.option("-c", "--config", default=None, type=click.Path(exists=True),
                     help="Use this top-level Jsonnet instead of the job's."),
        click.option("-n", "--dry-run", is_flag=True,
                     help="Print the environment and phlexed command; do not run."),
    ]
    for o in reversed(opts):
        f = o(f)
    return f


class Job:
    """A standard job: its Jsonnet, its TLAs and its own options."""

    def __init__(self, name, help, tlas, options=()):
        self.name = name
        self.help = help
        self.tlas = set(tlas)          # every TLA the job's Jsonnet accepts
        self.options = list(options)   # (click option, TLA name) pairs

    def config(self) -> Path:
        return runner.cfg_dir() / "xsj" / "jobs" / f"{self.name}.jsonnet"

    def command(self) -> click.Command:
        job = self

        def callback(**kw):
            sys.exit(job.invoke(kw))

        cb = common_options(callback)
        for opt, _ in reversed(self.options):
            cb = opt(cb)
        return click.command(self.name, help=self.help, context_settings=CONTEXT)(cb)

    def invoke(self, kw) -> int:
        tlas = {}

        def put(name, value):
            if value is None:
                return
            if name not in self.tlas:
                raise click.UsageError(f"job '{self.name}' does not take '{name}'")
            tlas[name] = str(value)

        detector = kw["detector"]
        if detector is None and kw["input_"]:
            detector = guess_detector(kw["input_"])
        put("detector", detector)
        put("variant", kw["variant"])
        put("anodes", kw["anodes"])
        if kw["input_"] is not None:
            put("input", str(Path(kw["input_"]).resolve()))
        # phlex writes output relative to its CWD: always pass an absolute path.
        out = kw["output"] or f"{self.name}.h5"
        put("output", str(Path(out).resolve()))
        put("nevents", kw["nevents"])
        put("seed", kw["seed"])
        put("log_level", kw["log_level"])
        put("log_sink", kw["log_sink"])
        for _, name in self.options:
            put(name, kw.get(name))
        for item in kw["tlas"]:
            if "=" not in item:
                raise click.UsageError(f"-A wants NAME=VALUE, got '{item}'")
            k, v = item.split("=", 1)
            put(k, v)

        try:
            cfg = Path(kw["config"]).resolve() if kw["config"] else self.config()
            inv = runner.Invocation(config=cfg, tlas=tlas, threads=kw["threads"],
                                    log_level=kw["log_level"] or "")
            return runner.run(inv, dry_run=kw["dry_run"])
        except runner.Skip as err:
            click.echo(f"xsj {self.name}: SKIP: {err}", err=True)
            return runner.SKIP


COMMON_TLAS = ["detector", "variant", "anodes", "log_level", "log_sink",
               "output", "nevents", "seed"]


def opt(*decls, tla, **kw):
    """A job option that maps onto TLA `tla` (its click name must equal `tla`)."""
    return (click.option(*decls, tla, **kw), tla)


@click.group(context_settings=CONTEXT)
@click.version_option(package_name="xsj")
def main():
    """Run xerosere-jobs standard jobs.

    See 'xsj JOB -h' for a job's options and docs/cli.md for the conventions.
    """


@main.command("list")
def list_jobs():
    """List the standard jobs."""
    from .jobs import JOBS
    for j in JOBS:
        click.echo(f"{j.name:10s} {j.help.splitlines()[0]}")


def _register():
    from .jobs import JOBS
    for j in JOBS:
        main.add_command(j.command())


_register()
