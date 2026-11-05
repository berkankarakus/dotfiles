#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'bootstrap_spec: %s\n' "$1" >&2
  exit 1
}

for script in bootstrap-macos.sh bootstrap-macos-csharp.sh; do
  bash -n "$script"
done
[[ -x scripts/resource-watch.sh ]] || fail "the system resource monitor script is missing"
grep -Fq 'RESOURCE_WATCH_LABEL=' bootstrap-macos.sh || fail "bootstrap should install the resource monitor"
grep -Fq 'launchctl bootstrap' bootstrap-macos.sh || fail "bootstrap should load the resource monitor LaunchAgent"
grep -Fq 'com.neovim.resource-watch' templates/com.neovim.resource-watch.plist || fail "resource monitor plist is missing its label"
grep -Fq '/after/queries/*/' bootstrap-macos.sh || fail "main script should deploy the queries of every language"
[[ -z "$(find after/queries -mindepth 3 -name '*.scm')" ]] || fail "queries nested deeper than after/queries/<language>/ would not be deployed"
for language in c_sharp mssql json; do
  [[ -f "after/queries/$language/textobjects.scm" ]] || fail "missing textobjects query for $language"
done
grep -Fq '"c_sharp", "mssql", "json"' bootstrap-macos.sh || fail "the json parser should be installed"
grep -Fq 'for parser in c_sharp mssql json' bootstrap-macos.sh || fail "the json parser should be verified"
grep -Eq 'brew install .* jq ' bootstrap-macos.sh || fail "jq should be installed for JSON formatting"
grep -Fq 'command -v jq' bootstrap-macos.sh || fail "jq should be verified"

# Every Lua module must be deployed, including plugin specs and native LSP configurations.
grep -Fq '/lua/neo/plugins/*.lua' bootstrap-macos.sh || fail "plugin spec modules should be deployed"
grep -Fq '/lua/neo/csharp/*.lua' bootstrap-macos.sh || fail "nested C# modules should be deployed"
grep -Fq '/lua/neo/doctor/*.lua' bootstrap-macos.sh || fail "nested doctor modules should be deployed"
grep -Fq '/lua/neo/textobjects/*.lua' bootstrap-macos.sh || fail "nested textobject modules should be deployed"
grep -Fq '/lua/neo/sqldeps/*.lua' bootstrap-macos.sh || fail "nested sqldeps modules should be deployed"
grep -Fq '/lua/neo/call_parens/*.lua' bootstrap-macos.sh || fail "nested call_parens modules should be deployed"
grep -Fq '/lua/neo/lsp/*.lua' bootstrap-macos.sh || fail "nested LSP modules should be deployed"
grep -Fq '/lua/lsp/*.lua' bootstrap-macos.sh || fail "LSP configuration modules should be deployed"
grep -Fq '"$NVIM_DIR/lua/neo/plugins"' bootstrap-macos.sh || fail "the plugins directory should be created before copying"
grep -Fq '"$NVIM_DIR/lua/neo/csharp"' bootstrap-macos.sh || fail "the nested C# directory should be created before copying"
grep -Fq '"$NVIM_DIR/lua/neo/doctor"' bootstrap-macos.sh || fail "the nested doctor directory should be created before copying"
grep -Fq '"$NVIM_DIR/lua/neo/textobjects"' bootstrap-macos.sh || fail "the nested textobject directory should be created before copying"
grep -Fq '"$NVIM_DIR/lua/neo/sqldeps"' bootstrap-macos.sh || fail "the nested sqldeps directory should be created before copying"
grep -Fq '"$NVIM_DIR/lua/neo/call_parens"' bootstrap-macos.sh || fail "the nested call_parens directory should be created before copying"
grep -Fq '"$NVIM_DIR/lua/neo/lsp"' bootstrap-macos.sh || fail "the nested LSP directory should be created before copying"
grep -Fq '"$NVIM_DIR/lua/lsp"' bootstrap-macos.sh || fail "the LSP directory should be created before copying"
grep -Fq 'SQLDEPS_REPOSITORY=' bootstrap-macos.sh || fail "sqldeps should be available to bootstrap"
grep -Fq '"$SQLDEPS_DIR/install.sh"' bootstrap-macos.sh || fail "sqldeps should be installed during bootstrap"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/lua/neo/plugins"
touch "$work/lua/neo/a.lua" "$work/lua/neo/plugins/b.lua"
deployed=$(for module in "$work"/lua/neo/*.lua "$work"/lua/neo/plugins/*.lua; do printf '%s\n' "${module#"$work"/lua/neo/}"; done)
[[ "$deployed" == $'a.lua\nplugins/b.lua' ]] || fail "module destination paths should keep the plugins/ subdirectory"
# Every module that exists in the repo must be covered by one of the deployment globs.
for module in lua/neo/*.lua lua/neo/plugins/*.lua lua/neo/csharp/*.lua lua/neo/doctor/*.lua lua/neo/textobjects/*.lua lua/neo/sqldeps/*.lua lua/neo/call_parens/*.lua lua/neo/lsp/*.lua lua/lsp/*.lua; do
  [[ -f "$module" ]] || fail "unexpected non-file $module"
done
[[ -z "$(find lua -mindepth 3 -name '*.lua' -not -path 'lua/neo/plugins/*' -not -path 'lua/neo/csharp/*' -not -path 'lua/neo/doctor/*' -not -path 'lua/neo/textobjects/*' -not -path 'lua/neo/sqldeps/*' -not -path 'lua/neo/call_parens/*' -not -path 'lua/neo/lsp/*' -not -path 'lua/lsp/*')" ]] || fail "a Lua module sits in a directory the bootstrap does not deploy"

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

# The zsh file is overwritten from the template, so the previous copy must be kept.
zsh_line=$(grep -n 'install -m 644 "$SOURCE_DIR/templates/neovim-csharp.zsh" "$ZSH_DIR' bootstrap-macos.sh | cut -d: -f1)
backup_line=$(grep -n 'backup_if_present "$ZSH_DIR/neovim-csharp.zsh"' bootstrap-macos.sh | cut -d: -f1)
[[ -n "$zsh_line" && -n "$backup_line" && "$backup_line" -lt "$zsh_line" ]] || fail "the zsh file should be backed up before it is overwritten"

# Mason downloaded an x64-only netcoredbg that is never used (the debugger adapter ships its own arm64
# binary) and printed tar output that looked like an error.
if grep -Fq 'Mason' bootstrap-macos.sh; then
  fail "the bootstrap should not install anything through Mason"
fi
if grep -Fq 'mason' lazy-lock.json; then
  fail "lazy-lock.json should not list Mason plugins"
fi

# Options are parsed before anything is installed.
help_output=$(./bootstrap-macos.sh --help)
grep -Fq -- '--no-elm' <<<"$help_output" || fail "--help should document --no-elm"
grep -Fq -- '--with-mono' <<<"$help_output" || fail "--help should document --with-mono"
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

# Mono and its debug adapter are opt-in: off by default, installed only for --with-mono, and the
# downloaded archive is verified against a pinned SHA-256 before it is extracted.
grep -Fq 'WITH_MONO=false' bootstrap-macos.sh || fail "Mono should be off by default"
grep -Fq -- '--with-mono) WITH_MONO=true' bootstrap-macos.sh || fail "--with-mono should enable Mono"
awk '/WITH_MONO.*== true/ { found = 1 } END { exit !found }' bootstrap-macos.sh || fail "Mono steps should be gated by WITH_MONO"
grep -Eq 'MONO_DEBUG_SHA256="[0-9a-f]{64}"' bootstrap-macos.sh || fail "the Mono debug adapter archive should be pinned by SHA-256"
verify_line=$(grep -n 'shasum -a 256 -c' bootstrap-macos.sh | head -1 | cut -d: -f1)
extract_line=$(grep -n "unzip -q" bootstrap-macos.sh | head -1 | cut -d: -f1)
[[ -n "$verify_line" && -n "$extract_line" && "$verify_line" -lt "$extract_line" ]] || fail "the archive hash should be verified before extraction"

printf 'bootstrap_spec: ok\n'
