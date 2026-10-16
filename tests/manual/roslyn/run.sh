#!/usr/bin/env bash
# Manual checks against a real Roslyn server. Not part of tests/run.sh: they are
# slow and need ~/.dotnet/tools/roslyn-language-server plus a restorable project.
#
#   tests/manual/roslyn/run.sh signature_help   # arity per signature after "()"
#   tests/manual/roslyn/run.sh cmp_flow         # real completion + cursor placement
set -euo pipefail

script=${1:?usage: run.sh signature_help|cmp_flow}
root=$(cd "$(dirname "$0")/../../.." && pwd)
work=$(mktemp -d /private/tmp/nvim-roslyn-manual.XXXXXX)
trap 'rm -rf "$work"' EXIT

cp "$root"/tests/manual/roslyn/{Probe.csproj,Program.cs,lib.lua,"$script".lua} "$work"/
cd "$work"
export PROBE_OUT="$work/out.txt" XDG_STATE_HOME="$work/state"

# macOS has no timeout(1); alarm gives a hard stop so a hung server cannot block.
if [[ $script == cmp_flow ]]; then
  perl -e 'alarm 150; exec @ARGV' nvim --headless -u "$root/init.lua" -i NONE Program.cs "+lua dofile('cmp_flow.lua')" >/dev/null 2>&1 || true
else
  perl -e 'alarm 120; exec @ARGV' nvim --headless -u "$root/init.lua" -i NONE Program.cs "+luafile $script.lua" >/dev/null 2>&1 || true
fi
cat "$PROBE_OUT" 2>/dev/null || echo "no output (Roslyn did not attach or the run timed out)"
