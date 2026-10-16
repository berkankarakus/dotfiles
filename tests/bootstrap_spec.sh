#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'bootstrap_spec: %s\n' "$1" >&2
  exit 1
}

for script in bootstrap-macos.sh bootstrap-macos-csharp.sh; do
  bash -n "$script"
done
grep -Fq 'after/queries/mssql' bootstrap-macos.sh || fail "main script should deploy the mssql queries"

# The C# variant is a thin wrapper, so it cannot drift from the main script.
grep -Fq -- 'bootstrap-macos.sh" --no-elm' bootstrap-macos-csharp.sh || fail "wrapper should delegate with --no-elm"
[[ $(wc -l < bootstrap-macos-csharp.sh) -le 10 ]] || fail "wrapper should stay a thin delegate"

# Options are parsed before anything is installed.
help_output=$(./bootstrap-macos.sh --help)
grep -Fq -- '--no-elm' <<<"$help_output" || fail "--help should document --no-elm"
[[ $(./bootstrap-macos-csharp.sh --help) == "$help_output" ]] || fail "wrapper --help should match the main script"

if ./bootstrap-macos.sh --definitely-unknown >/dev/null 2>&1; then
  fail "unknown options should be rejected"
fi

# Reproducibility: honour lazy-lock.json and pin the language server.
if grep -Fq 'Lazy! sync' bootstrap-macos.sh; then
  fail "Lazy sync updates past lazy-lock.json; use install + restore"
fi
grep -Fq "'+Lazy! install'" bootstrap-macos.sh || fail "missing plugins should be installed"
grep -Fq "'+Lazy! restore'" bootstrap-macos.sh || fail "plugins should be restored to lazy-lock.json"
grep -Eq '^ROSLYN_VERSION="[0-9][^"]+"' bootstrap-macos.sh || fail "Roslyn version should be pinned"
grep -Fq -- '--version "$ROSLYN_VERSION"' bootstrap-macos.sh || fail "Roslyn should be installed at the pinned version"
if grep -Eq 'roslyn-language-server --prerelease' bootstrap-macos.sh; then
  fail "Roslyn should not float on --prerelease"
fi

# Failures must be visible instead of swallowed by `|| true`.
if grep -Eq "nvim --headless .*\|\| true" bootstrap-macos.sh; then
  fail "headless nvim steps should not swallow failures with || true"
fi
grep -Fq 'Verifying installation' bootstrap-macos.sh || fail "a verification summary should run at the end"

# Elm tooling is optional.
awk '/WITH_ELM.*== true/ { found = 1 } END { exit !found }' bootstrap-macos.sh || fail "Elm steps should be gated by WITH_ELM"

printf 'bootstrap_spec: ok\n'
