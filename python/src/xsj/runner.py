"""Resolve a job invocation into a phlexed command line and environment, and run it."""

import os
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

SKIP = 77  # exit code: skipped (missing prerequisite), as in the old test scripts


class Skip(Exception):
    """A prerequisite is missing: exit with SKIP."""


@dataclass
class Invocation:
    config: Path                       # the job's top-level Jsonnet
    tlas: dict = field(default_factory=dict)   # TLA name -> string value
    threads: int | None = None
    log_level: str = ""
    env: dict = field(default_factory=dict)    # extra environment

    def command(self, phlexed: str = "phlexed") -> list[str]:
        cmd = [phlexed, "-c", str(self.config)]
        if self.threads:
            cmd += ["-j", str(self.threads)]
        for k, v in self.tlas.items():
            cmd += ["-A", f"{k}={v}"]
        return cmd


def prefix() -> Path | None:
    """The install prefix holding share/xerosere-jobs, phlexed and the plugins.

    XSJ_PREFIX wins, else the prefix of the phlexed found on PATH."""
    p = os.environ.get("XSJ_PREFIX")
    if p:
        return Path(p)
    exe = shutil.which("phlexed")
    return Path(exe).resolve().parent.parent if exe else None


def cfg_dir() -> Path:
    """Directory holding xsj/{lib,jobs}/*.jsonnet.

    XSJ_CFG wins, then <prefix>/share/xerosere-jobs/cfg, then the source tree
    (for running from a checkout)."""
    p = os.environ.get("XSJ_CFG")
    if p:
        return Path(p)
    pre = prefix()
    if pre and (pre / "share/xerosere-jobs/cfg/xsj").is_dir():
        return pre / "share/xerosere-jobs/cfg"
    src = Path(__file__).resolve().parents[3] / "cfg"
    if (src / "xsj").is_dir():
        return src
    raise Skip("cannot find the xerosere-jobs configuration (set XSJ_CFG or XSJ_PREFIX)")


def _prepend(path_var: str, dirs: list[Path], env: dict) -> None:
    have = [d for d in env.get(path_var, "").split(":") if d]
    new = [str(d) for d in dirs if d.is_dir() and str(d) not in have]
    env[path_var] = ":".join(new + have)


def environment(extra: dict | None = None, log_level: str = "") -> dict:
    """The process environment for phlexed.

    Adds what can be derived from the install prefix; see docs/cli.md."""
    env = dict(os.environ)
    pre = prefix()
    cfg = cfg_dir()
    _prepend("PHLEXED_PATH", [cfg], env)
    if not pre:
        # WCT island configs of the jobs (xsj/wct/*.jsonnet) still need WIRECELL_PATH.
        _prepend("WIRECELL_PATH", [cfg], env)
    else:
        plugin_dirs = [pre / "lib", pre / "lib64"]
        # phlex's own plugins (eg generate_layers) are next to the phlex executable.
        phlex = shutil.which("phlex")
        if phlex:
            plugin_dirs.append(Path(phlex).resolve().parent.parent / "lib")
        _prepend("PHLEX_PLUGIN_PATH", plugin_dirs, env)
        # WCT job configs (wire-cell-phlex tree), then WCT's own Jsonnet.
        # Detector data (wire-cell-data) must already be on WIRECELL_PATH.
        wcp = [d for d in env.get("WIRECELL_PATH", "").split(":") if d]
        add = [cfg, pre / "share/wire-cell-phlex/cfg", pre / "share/wirecell"]
        env["WIRECELL_PATH"] = ":".join(
            [str(d) for d in add if d.is_dir() and str(d) not in wcp] + wcp)
    # Several WCT islands per event each run go-jsonnet; without this the Go
    # async preemption can deadlock (see the old tests/spdir/run.sh).
    gd = env.get("GODEBUG", "")
    if "asyncpreemptoff" not in gd:
        env["GODEBUG"] = (gd + "," if gd else "") + "asyncpreemptoff=1"
    if log_level:
        env["SPDLOG_LEVEL"] = log_level  # phlex calls spdlog::cfg::load_env_levels()
    env.update(extra or {})
    return env


def run(inv: Invocation, dry_run: bool = False) -> int:
    phlexed = shutil.which("phlexed")
    if not phlexed and not dry_run:
        raise Skip("phlexed not found on PATH (activate the build environment)")
    env = environment(inv.env, inv.log_level)
    cmd = inv.command(phlexed or "phlexed")
    if dry_run:
        for k in ("PHLEXED_PATH", "PHLEX_PLUGIN_PATH", "WIRECELL_PATH", "GODEBUG", "SPDLOG_LEVEL"):
            if k in env:
                print(f"{k}={shlex.quote(env[k])}")
        print(shlex.join(cmd))
        return 0
    print("+ " + shlex.join(cmd), file=sys.stderr)
    return subprocess.call(cmd, env=env)
