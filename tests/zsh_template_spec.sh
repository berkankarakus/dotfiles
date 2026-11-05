#!/usr/bin/env bash
# templates/neovim-csharp.zsh is what the bootstrap deploys to ~/.config/zsh. A tweak made only in the
# deployed file never reaches other Macs, so the intended behaviour is pinned here and in the README.
set -euo pipefail

template=templates/neovim-csharp.zsh

fail() {
  printf 'zsh_template_spec: %s\n' "$1" >&2
  exit 1
}

zsh -n "$template" || fail "the template has a syntax error"

# Ctrl-g takes the suggestion into the prompt; Enter only runs what is typed.
grep -Fq "bindkey '^G' autosuggest-accept" "$template" || fail "Ctrl-g should accept the autosuggestion"
grep -Fq "bindkey '^M' accept-line" "$template" || fail "Enter should just run the command line"
if grep -Fq 'accept_suggestion_or_line' "$template"; then
  fail "Enter must not accept the suggestion any more (Ctrl-g does)"
fi
if grep -Fq "bindkey '^G' autosuggest-clear" "$template"; then
  fail "Ctrl-g must not clear the suggestion any more"
fi

# The README documents the same behaviour.
grep -Fq '| `Ctrl-g` | Accept the faded history suggestion without executing it |' README.md || fail "the README should describe Ctrl-g accepting the suggestion"
grep -Fq '| `Enter` | Run the command currently typed at the prompt |' README.md || fail "the README should describe Enter just running the command"

printf 'zsh_template_spec: ok\n'
