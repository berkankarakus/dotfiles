#!/usr/bin/env bash
# Run from a copy/clone of this nvim configuration on a new macOS machine.
#
#   ./bootstrap-macos.sh            full setup (C# + Elm)
#   ./bootstrap-macos.sh --no-elm   C#-focused setup without Elm tooling
set -euo pipefail

# Pinned so every machine gets the same language server; bump deliberately.
ROSLYN_VERSION="5.12.0-1.26426.8"
WITH_ELM=true

for argument in "$@"; do
  case "$argument" in
    --no-elm) WITH_ELM=false ;;
    -h|--help)
      sed -n '3,5p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $argument (try --help)" >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap is for macOS only." >&2
  exit 1
fi

SOURCE_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
NVIM_DIR="$HOME/.config/nvim"
GHOSTTY_DIR="$HOME/.config/ghostty"
ZSH_DIR="$HOME/.config/zsh"
BACKUP_DIR="$HOME/.config/neovim-csharp-backup/$(date +%Y%m%d-%H%M%S)"

backup_if_present() {
  local path="$1"
  if [[ -e "$path" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -Rp "$path" "$BACKUP_DIR/$(basename "$path")"
  fi
}

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
BREW_BIN="$(command -v brew || true)"
if [[ -z "$BREW_BIN" && -x /opt/homebrew/bin/brew ]]; then BREW_BIN=/opt/homebrew/bin/brew; fi
if [[ -z "$BREW_BIN" && -x /usr/local/bin/brew ]]; then BREW_BIN=/usr/local/bin/brew; fi
eval "$("$BREW_BIN" shellenv)"

echo "Installing development tools..."
brew install neovim ripgrep fzf zoxide fd bat git jq terminal-notifier tree-sitter-cli
if [[ "$WITH_ELM" == true ]]; then
  brew install fossil elm elm-format node
fi

# `brew install --cask` refuses to overwrite an app or font that Homebrew did not install (Ghostty from
# the .dmg, a font copied by hand). With `set -e` that single error stopped the whole bootstrap before
# Roslyn, the plugin restore and the parsers. So a cask is only installed when what it provides is missing.
install_cask() {
  local cask="$1"; shift
  if brew list --cask "$cask" >/dev/null 2>&1; then
    echo "  $cask: already installed with Homebrew"
  elif "$@" >/dev/null 2>&1; then
    echo "  $cask: already present outside Homebrew, leaving it alone"
  else
    brew install --cask "$cask"
  fi
}
font_installed() {
  compgen -G "$HOME/Library/Fonts/JetBrainsMono*NerdFont*" >/dev/null || compgen -G "/Library/Fonts/JetBrainsMono*NerdFont*" >/dev/null
}
dotnet_installed() { command -v dotnet >/dev/null 2>&1 || [[ -x /usr/local/share/dotnet/dotnet ]]; }
install_cask ghostty test -d /Applications/Ghostty.app
install_cask font-jetbrains-mono-nerd-font font_installed
install_cask dotnet-sdk dotnet_installed

echo "Installing Roslyn language server $ROSLYN_VERSION..."
installed_roslyn="$(dotnet tool list -g | awk '$1 == "roslyn-language-server" { print $2 }')"
if [[ "$installed_roslyn" != "$ROSLYN_VERSION" ]]; then
  if [[ -n "$installed_roslyn" ]]; then dotnet tool uninstall -g roslyn-language-server; fi
  dotnet tool install -g roslyn-language-server --version "$ROSLYN_VERSION"
fi

if [[ "$WITH_ELM" == true ]]; then
  echo "Installing Elm language server and test runner..."
  npm install -g elm-test @elm-tooling/elm-language-server
fi

echo "Installing Zsh autosuggestions..."
mkdir -p "$ZSH_DIR/plugins"
if [[ ! -d "$ZSH_DIR/plugins/zsh-autosuggestions/.git" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_DIR/plugins/zsh-autosuggestions"
fi

echo "Deploying configuration (old files are backed up when replaced)..."
mkdir -p "$NVIM_DIR" "$GHOSTTY_DIR" "$ZSH_DIR"
if [[ "$SOURCE_DIR" != "$NVIM_DIR" ]]; then
  for path in init.lua lazy-lock.json README.md bootstrap-macos.sh bootstrap-macos-csharp.sh lua after templates; do
    backup_if_present "$NVIM_DIR/$path"
  done
  install -d -m 755 "$NVIM_DIR/lua/neo" "$NVIM_DIR/lua/neo/plugins" "$NVIM_DIR/templates"
  install -m 644 "$SOURCE_DIR/init.lua" "$NVIM_DIR/init.lua"
  install -m 644 "$SOURCE_DIR/lazy-lock.json" "$NVIM_DIR/lazy-lock.json"
  install -m 644 "$SOURCE_DIR/README.md" "$NVIM_DIR/README.md"
  install -m 755 "$SOURCE_DIR/bootstrap-macos.sh" "$NVIM_DIR/bootstrap-macos.sh"
  install -m 755 "$SOURCE_DIR/bootstrap-macos-csharp.sh" "$NVIM_DIR/bootstrap-macos-csharp.sh"
  for module in "$SOURCE_DIR"/lua/neo/*.lua "$SOURCE_DIR"/lua/neo/plugins/*.lua; do
    install -m 644 "$module" "$NVIM_DIR/lua/neo/${module#"$SOURCE_DIR"/lua/neo/}"
  done
  # One directory per language (c_sharp, mssql, json, ...); new languages need no script change.
  for query_dir in "$SOURCE_DIR"/after/queries/*/; do
    language="$(basename "$query_dir")"
    install -d -m 755 "$NVIM_DIR/after/queries/$language"
    for query in "$query_dir"*.scm; do
      install -m 644 "$query" "$NVIM_DIR/after/queries/$language/$(basename "$query")"
    done
  done
  install -m 644 "$SOURCE_DIR/templates/ghostty-config" "$NVIM_DIR/templates/ghostty-config"
  install -m 644 "$SOURCE_DIR/templates/neovim-csharp.zsh" "$NVIM_DIR/templates/neovim-csharp.zsh"
fi

backup_if_present "$GHOSTTY_DIR/config"
install -m 644 "$SOURCE_DIR/templates/ghostty-config" "$GHOSTTY_DIR/config"
# This file is easy to tweak in place; keep the previous copy so a re-run never silently discards it.
backup_if_present "$ZSH_DIR/neovim-csharp.zsh"
install -m 644 "$SOURCE_DIR/templates/neovim-csharp.zsh" "$ZSH_DIR/neovim-csharp.zsh"

if ! grep -Fq 'source "$HOME/.config/zsh/neovim-csharp.zsh"' "$HOME/.zshrc" 2>/dev/null; then
  {
    printf '\n# Neovim C# bootstrap\n'
    printf 'source "$HOME/.config/zsh/neovim-csharp.zsh"\n'
  } >> "$HOME/.zshrc"
fi

echo "Installing Neovim plugins and C# debugger..."
LAZY_DIR="$HOME/.local/share/nvim/lazy/lazy.nvim"
if [[ ! -d "$LAZY_DIR/.git" ]]; then
  mkdir -p "$(dirname "$LAZY_DIR")"
  git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$LAZY_DIR"
fi
# install clones what is missing, restore then pins every plugin to lazy-lock.json
# (`Lazy sync` would update to the newest commits and drift from this machine).
nvim --headless '+Lazy! install' '+qa' || echo "warning: Lazy install reported a problem" >&2
nvim --headless '+Lazy! restore' '+qa' || echo "warning: Lazy restore reported a problem" >&2

PARSERS='"c_sharp", "mssql", "json"'
if [[ "$WITH_ELM" == true ]]; then PARSERS="$PARSERS, \"elm\""; fi
nvim --headless "+lua local ok, err = pcall(function() require('nvim-treesitter').install({ $PARSERS }):wait(300000) end) if not ok then print(err) end" '+qa' \
  || echo "warning: Tree-sitter parser install reported a problem" >&2

echo
echo "Verifying installation..."
FAILED=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok       %s\n' "$label"
  else
    printf '  MISSING  %s\n' "$label"
    FAILED=1
  fi
}
roslyn_is_pinned() {
  [[ "$(dotnet tool list -g | awk '$1 == "roslyn-language-server" { print $2 }')" == "$ROSLYN_VERSION" ]]
}
check "roslyn-language-server $ROSLYN_VERSION" roslyn_is_pinned
check "netcoredbg debugger" test -x "$HOME/.local/share/nvim/lazy/netcoredbg-macOS-arm64.nvim/netcoredbg/netcoredbg"
check "Ghostty" test -d /Applications/Ghostty.app
check "JetBrainsMono Nerd Font" font_installed
check "jq (JSON formatting)" command -v jq
for parser in c_sharp mssql json; do
  check "Tree-sitter parser: $parser" test -f "$HOME/.local/share/nvim/site/parser/$parser.so"
done
if [[ "$WITH_ELM" == true ]]; then
  check "Tree-sitter parser: elm" test -f "$HOME/.local/share/nvim/site/parser/elm.so"
  check "elm-language-server" command -v elm-language-server
fi

if [[ "$FAILED" -ne 0 ]]; then
  echo
  echo "Some components are missing; re-run this script or install them by hand." >&2
  exit 1
fi

cat <<'EOF'

Done. Open a new Ghostty tab (or run `exec zsh`) and start Neovim with `nvim`.
Existing replaced config files, if any, were backed up under ~/.config/neovim-csharp-backup.
EOF
