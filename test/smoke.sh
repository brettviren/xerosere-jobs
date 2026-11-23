#!/usr/bin/env bash
# smoke.sh CFGDIR JOB [PATTERN ...] -- [TLA=VALUE ...]
#
# Run cfg/xsj/jobs/JOB.jsonnet through phlexed in a temporary directory and
# check that `h5ls -r` of the output matches every PATTERN (grep -E).
# Needs an activated environment: phlexed and h5ls on PATH, the plugins on
# PHLEX_PLUGIN_PATH and detector data on WIRECELL_PATH.  Exit 77 = skipped.
set -uo pipefail
cfg="$1"; job="$2"; shift 2
pats=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do pats+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
say() { echo "[smoke $job] $*" >&2; }
command -v phlexed >/dev/null || { say "SKIP: no phlexed"; exit 77; }
command -v h5ls >/dev/null    || { say "SKIP: no h5ls"; exit 77; }

prefix="$(cd "$(dirname "$(command -v phlexed)")/.." && pwd)"
export PHLEXED_PATH="$cfg${PHLEXED_PATH:+:$PHLEXED_PATH}"
# phlex's own plugins (generate_layers) live next to the phlex executable.
plib=""
command -v phlex >/dev/null && plib=":$(cd "$(dirname "$(command -v phlex)")/.." && pwd)/lib"
export PHLEX_PLUGIN_PATH="$prefix/lib$plib${PHLEX_PLUGIN_PATH:+:$PHLEX_PLUGIN_PATH}"
export WIRECELL_PATH="$cfg:$prefix/share/wire-cell-phlex/cfg:$prefix/share/wirecell${WIRECELL_PATH:+:$WIRECELL_PATH}"
export GODEBUG="${GODEBUG:+$GODEBUG,}asyncpreemptoff=1"

work="$(mktemp -d -t "xsj-$job-XXXX")"
out="$work/$job.h5"
args=(-c "$cfg/xsj/jobs/$job.jsonnet" -A "output=$out")
for t in "$@"; do args+=(-A "$t"); done
say "phlexed ${args[*]}"
if ! ( cd "$work" && phlexed "${args[@]}" ) > "$work/log" 2>&1; then
    tail -30 "$work/log" >&2
    say "FAIL: phlexed (log: $work/log)"
    exit 1
fi
[ -s "$out" ] || { say "FAIL: no output $out"; exit 1; }
listing="$(h5ls -r "$out")"
rc=0
for p in "${pats[@]}"; do
    if grep -qE "$p" <<<"$listing"; then say "ok: $p"; else say "MISSING: $p"; rc=1; fi
done
if [ $rc = 0 ]; then say "PASS ($work)"; else say "FAIL ($work)"; fi
exit $rc
