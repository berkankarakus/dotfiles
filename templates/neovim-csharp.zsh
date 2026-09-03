# Managed by the Neovim C# bootstrap. This file is sourced from ~/.zshrc.
export PATH="$HOME/.dotnet/tools:$HOME/.local/bin:/opt/homebrew/bin:$PATH"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_REDUCE_BLANKS
[[ -f "$HISTFILE" ]] && fc -R "$HISTFILE"

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

source "$HOME/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(accept_suggestion_or_line)
accept_suggestion_or_line() {
  if [[ -n "$POSTDISPLAY" ]]; then
    BUFFER="$BUFFER$POSTDISPLAY"
    CURSOR=$#BUFFER
    POSTDISPLAY=
  else
    zle .accept-line
  fi
}
zle -N accept_suggestion_or_line
bindkey '^M' accept_suggestion_or_line
bindkey '^J' accept_suggestion_or_line

# Option + Delete removes a word; fn + Delete removes the next character.
bindkey '^[^?' backward-kill-word
bindkey '^[^H' backward-kill-word
bindkey '^[[3~' delete-char

ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(fzf_history_widget)
fzf_history_widget() {
  local selection status
  selection=$(fc -rl 1 | awk '{ line = $0; sub(/^[[:space:]]*[0-9]+\\*?[[:space:]]+/, "", line); if (!seen[line]++) print line }' | fzf --height=45% --layout=reverse --border --prompt='History> ' --query="$LBUFFER")
  status=$?
  if (( status != 0 )); then
    zle reset-prompt
    return
  fi
  BUFFER="$selection"
  CURSOR=$#BUFFER
  zle reset-prompt
}
zle -N fzf_history_widget
bindkey '^R' fzf_history_widget
