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
ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(autosuggest-clear)
bindkey '^G' autosuggest-clear

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

# Option + Delete removes the next word.
bindkey '^[d' kill-word

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

fossil() {
  if [[ "$1" == "diff" ]]; then
    shift
    command fossil diff "$@" | less -R
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "status" ]]; then
    shift
    command fossil status "$@" | awk '
      /^ADDED[[:space:]]/    { color="\033[1;36m" }
      /^EDITED[[:space:]]/   { color="\033[33m" }
      /^DELETED[[:space:]]/  { color="\033[31m" }
      /^MISSING[[:space:]]/  { color="\033[31m" }
      /^RENAMED[[:space:]]/  { color="\033[36m" }
      /^CONFLICT[[:space:]]/ { color="\033[35m" }
      { print (color ? color : "") $0 (color ? "\033[0m" : ""); color="" }
    '
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "timeline" ]]; then
    shift
    command fossil timeline "$@" | awk '
      /^=== / { print "\033[1;36m" $0 "\033[0m"; next }
      {
        line = $0
        if (match(line, /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) {
          line = "\033[2m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /\[[0-9a-f]+\]/)) {
          line = substr(line, 1, RSTART - 1) "\033[1;33m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /(feat|fix|refactor|chore|docs|test):/)) {
          kind = substr(line, RSTART, RLENGTH)
          color = kind ~ /^feat:/ ? "\033[1;32m" : kind ~ /^fix:/ ? "\033[1;33m" : kind ~ /^refactor:/ ? "\033[1;35m" : "\033[1;34m"
          line = substr(line, 1, RSTART - 1) color kind "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /\(user: [^)]+\)/)) {
          line = substr(line, 1, RSTART - 1) "\033[36m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /tags: [^)]+/)) {
          line = substr(line, 1, RSTART - 1) "\033[2;34m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        print line
      }
    '
    return ${pipestatus[1]}
  fi
  command fossil "$@"
}
