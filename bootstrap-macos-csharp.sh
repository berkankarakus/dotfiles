#!/usr/bin/env bash
# C#-focused bootstrap without Elm tooling. Kept as a thin wrapper so the two
# variants cannot drift apart; all logic lives in bootstrap-macos.sh.
set -euo pipefail
exec "$(cd -- "$(dirname -- "$0")" && pwd -P)/bootstrap-macos.sh" --no-elm "$@"
