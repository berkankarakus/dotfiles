#!/usr/bin/env bash
# Run from a copy/clone of this nvim configuration on a new macOS machine.
set -euo pipefail

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
brew install neovim ripgrep fzf zoxide fd bat git fossil elm elm-format node tree-sitter-cli
brew install --cask ghostty font-jetbrains-mono-nerd-font dotnet-sdk

echo "Installing Roslyn language server..."
dotnet tool install -g roslyn-language-server --prerelease || \
  dotnet tool update -g roslyn-language-server --prerelease

echo "Installing Elm language server and test runner..."
npm install -g elm-test @elm-tooling/elm-language-server

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
  install -d -m 755 "$NVIM_DIR/lua/neo" "$NVIM_DIR/after/queries/c_sharp" "$NVIM_DIR/templates"
  install -m 644 "$SOURCE_DIR/init.lua" "$NVIM_DIR/init.lua"
  install -m 644 "$SOURCE_DIR/lazy-lock.json" "$NVIM_DIR/lazy-lock.json"
  install -m 644 "$SOURCE_DIR/README.md" "$NVIM_DIR/README.md"
  install -m 755 "$SOURCE_DIR/bootstrap-macos.sh" "$NVIM_DIR/bootstrap-macos.sh"
  install -m 755 "$SOURCE_DIR/bootstrap-macos-csharp.sh" "$NVIM_DIR/bootstrap-macos-csharp.sh"
  for module in "$SOURCE_DIR"/lua/neo/*.lua; do
    install -m 644 "$module" "$NVIM_DIR/lua/neo/$(basename "$module")"
  done
  install -m 644 "$SOURCE_DIR/after/queries/c_sharp/folds.scm" "$NVIM_DIR/after/queries/c_sharp/folds.scm"
  install -m 644 "$SOURCE_DIR/templates/ghostty-config" "$NVIM_DIR/templates/ghostty-config"
  install -m 644 "$SOURCE_DIR/templates/neovim-csharp.zsh" "$NVIM_DIR/templates/neovim-csharp.zsh"
fi

backup_if_present "$GHOSTTY_DIR/config"
install -m 644 "$SOURCE_DIR/templates/ghostty-config" "$GHOSTTY_DIR/config"
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
nvim --headless '+Lazy! sync' '+qa' || true
nvim --headless '+MasonInstall netcoredbg' '+qa' || true
nvim --headless '+TSInstall elm' '+lua vim.wait(120000, function() return vim.fn.filereadable(vim.fn.stdpath("data") .. "/site/parser/elm.so") == 1 end, 100)' '+qa' || true

cat <<'EOF'

Done. Open a new Ghostty tab (or run `exec zsh`) and start Neovim with `nvim`.
Existing replaced config files, if any, were backed up under ~/.config/neovim-csharp-backup.
EOF
