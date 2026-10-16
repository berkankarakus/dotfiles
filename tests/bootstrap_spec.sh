#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'bootstrap_spec: %s\n' "$1" >&2
  exit 1
}

for script in bootstrap-macos.sh bootstrap-macos-csharp.sh; do
  bash -n "$script"
done
grep -Fq '/after/queries/*/' bootstrap-macos.sh || fail "main script should deploy the queries of every language"
[[ -z "$(find after/queries -mindepth 3 -name '*.scm')" ]] || fail "queries nested deeper than after/queries/<language>/ would not be deployed"
for language in c_sharp mssql json; do
  [[ -f "after/queries/$language/textobjects.scm" ]] || fail "missing textobjects query for $language"
done
grep -Fq '"c_sharp", "mssql", "json"' bootstrap-macos.sh || fail "the json parser should be installed"
grep -Fq 'for parser in c_sharp mssql json' bootstrap-macos.sh || fail "the json parser should be verified"
grep -Eq 'brew install .* jq ' bootstrap-macos.sh || fail "jq should be installed for JSON formatting"
grep -Fq 'command -v jq' bootstrap-macos.sh || fail "jq should be verified"

# Every Lua module must be deployed, including the plugin spec modules in lua/neo/plugins/.
grep -Fq '/lua/neo/plugins/*.lua' bootstrap-macos.sh || fail "plugin spec modules should be deployed"
grep -Fq '"$NVIM_DIR/lua/neo/plugins"' bootstrap-macos.sh || fail "the plugins directory should be created before copying"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/lua/neo/plugins"
touch "$work/lua/neo/a.lua" "$work/lua/neo/plugins/b.lua"
deployed=$(for module in "$work"/lua/neo/*.lua "$work"/lua/neo/plugins/*.lua; do printf '%s\n' "${module#"$work"/lua/neo/}"; done)
[[ "$deployed" == $'a.lua\nplugins/b.lua' ]] || fail "module destination paths should keep the plugins/ subdirectory"
# Every module that exists in the repo must be covered by one of the two globs.
for module in lua/neo/*.lua lua/neo/plugins/*.lua; do
  [[ -f "$module" ]] || fail "unexpected non-file $module"
done
[[ -z "$(find lua -mindepth 3 -name '*.lua' -not -path 'lua/neo/plugins/*')" ]] || fail "a Lua module sits in a directory the bootstrap does not deploy"

# The C# variant is a thin wrapper, so it cannot drift from the main script.
grep -Fq -- 'bootstrap-macos.sh" --no-elm' bootstrap-macos-csharp.sh || fail "wrapper should delegate with --no-elm"
[[ $(wc -l < bootstrap-macos-csharp.sh) -le 10 ]] || fail "wrapper should stay a thin delegate"

# A cask that is already there (Ghostty from the .dmg, a hand-copied font) must not abort the script:
# `brew install --cask` errors on it and `set -e` would skip Roslyn, the plugin restore and the parsers.
if grep -Eq '^brew install --cask ' bootstrap-macos.sh; then
  fail "casks must go through install_cask, not a bare brew install --cask"
fi
for cask in ghostty font-jetbrains-mono-nerd-font dotnet-sdk; do
  grep -Eq "^install_cask $cask " bootstrap-macos.sh || fail "$cask should be installed through install_cask"
done
grep -Fq 'check "JetBrainsMono Nerd Font" font_installed' bootstrap-macos.sh || fail "the font should be verified"

# Run the real install_cask against a fake brew.
bin="$work/bin"
mkdir -p "$bin"
cat >"$bin/brew" <<'FAKE'
#!/usr/bin/env bash
echo "brew $*" >>"$BREW_LOG"
if [[ "$1" == list && "$2" == --cask ]]; then
  [[ " $BREW_INSTALLED " == *" $3 "* ]]
  exit
fi
exit 0
FAKE
chmod +x "$bin/brew"
awk '/^install_cask\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' bootstrap-macos.sh >"$work/install_cask.sh"
[[ -s "$work/install_cask.sh" ]] || fail "install_cask should be defined in the script"

run_install_cask() { # $1 = space separated casks Homebrew already manages, then the cask and its presence test
  local managed="$1"; shift
  : >"$work/brew.log"
  PATH="$bin:$PATH" BREW_LOG="$work/brew.log" BREW_INSTALLED="$managed" \
    bash -c "set -euo pipefail; source '$work/install_cask.sh'; install_cask \"\$@\"" _ "$@"
}

out=$(run_install_cask "ghostty" ghostty false)
! grep -q 'install --cask' "$work/brew.log" || fail "a Homebrew-managed cask should not be installed again"
[[ "$out" == *"already installed with Homebrew"* ]] || fail "managed cask: unexpected output: $out"

out=$(run_install_cask "" ghostty true)
! grep -q 'install --cask' "$work/brew.log" || fail "a cask whose app already exists should be left alone"
[[ "$out" == *"outside Homebrew"* ]] || fail "unmanaged cask: unexpected output: $out"

run_install_cask "" ghostty false >/dev/null
grep -qx 'brew install --cask ghostty' "$work/brew.log" || fail "a missing cask should be installed"

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
