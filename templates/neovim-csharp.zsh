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
  if [[ "$1" == "status" || "$1" == "changes" || "$1" == "addremove" ]]; then
    local subcommand=$1
    shift
    command fossil "$subcommand" "$@" | awk '
      function print_info(value_color) {
        if (match($0, /^[^:]+:/)) {
          print "\033[38;5;67m" substr($0, 1, RLENGTH) "\033[0m" value_color substr($0, RLENGTH + 1) "\033[0m"
        } else {
          print
        }
      }
      /^(repository|local-root|config-db):/ { print_info("\033[38;5;109m"); next }
      /^(checkout|parent):/ { print_info("\033[38;5;180m"); next }
      /^tags:/ { print_info("\033[38;5;139m"); next }
      /^comment:/ { print_info("\033[38;5;108m"); next }
      /^ADDED[[:space:]]/    { color="\033[38;5;110m" }
      /^EDITED[[:space:]]/   { color="\033[38;5;180m" }
      /^DELETED[[:space:]]/  { color="\033[38;5;167m" }
      /^MISSING[[:space:]]/  { color="\033[38;5;167m" }
      /^RENAMED[[:space:]]/  { color="\033[38;5;109m" }
      /^CONFLICT[[:space:]]/ { color="\033[38;5;139m" }
      /^added [0-9]+ files, deleted [0-9]+ files$/ { color="\033[38;5;250m" }
      { print (color ? color : "") $0 (color ? "\033[0m" : ""); color="" }
    '
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "extras" ]]; then
    shift
    command fossil extras "$@" | awk '{ print "\033[38;5;110m" $0 "\033[0m" }'
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "timeline" ]]; then
    shift
    command fossil timeline "$@" | awk '
      /^=== / { print "\033[38;5;110m" $0 "\033[0m"; next }
      {
        line = $0
        if (match(line, /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) {
          line = "\033[2m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /\[[0-9a-f]+\]/)) {
          line = substr(line, 1, RSTART - 1) "\033[38;5;180m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /(feat|fix|refactor|chore|docs|test):/)) {
          kind = substr(line, RSTART, RLENGTH)
          color = kind ~ /^feat:/ ? "\033[38;5;108m" : kind ~ /^fix:/ ? "\033[38;5;180m" : kind ~ /^refactor:/ ? "\033[38;5;139m" : "\033[38;5;67m"
          line = substr(line, 1, RSTART - 1) color kind "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /\(user: [^)]+\)/)) {
          line = substr(line, 1, RSTART - 1) "\033[38;5;109m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /tags: [^)]+/)) {
          line = substr(line, 1, RSTART - 1) "\033[38;5;61m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        print line
      }
    '
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "branch" && ( "$2" == "list" || "$2" == "ls" || "$2" == "lsh" ) ]]; then
    local subcommand=$2
    shift 2
    command fossil branch "$subcommand" "$@" | awk '
      /\*/ { print "\033[38;5;108m" $0 "\033[0m"; next }
      /#/  { print "\033[38;5;139m" $0 "\033[0m"; next }
      { print "\033[38;5;109m" $0 "\033[0m" }
    '
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "tag" && ( "$2" == "list" || "$2" == "ls" ) ]]; then
    local subcommand=$2
    shift 2
    command fossil tag "$subcommand" "$@" | awk '
      /^sym-/ { print "\033[38;5;108m" $0 "\033[0m"; next }
      /^(branch|closed|hidden|private)$/ { print "\033[38;5;139m" $0 "\033[0m"; next }
      { print "\033[38;5;109m" $0 "\033[0m" }
    '
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "info" ]]; then
    shift
    command fossil info "$@" | awk '
      function print_info(value_color) {
        if (match($0, /^[^:]+:/)) {
          print "\033[38;5;67m" substr($0, 1, RLENGTH) "\033[0m" value_color substr($0, RLENGTH + 1) "\033[0m"
        } else {
          print
        }
      }
      /^(repository|local-root|config-db):/ { print_info("\033[38;5;109m"); next }
      /^(checkout|parent):/ { print_info("\033[38;5;180m"); next }
      /^tags:/ { print_info("\033[38;5;139m"); next }
      /^comment:/ { print_info("\033[38;5;108m"); next }
      {
        line = $0
        if (match(line, /^[^:]+:/)) {
          line = "\033[38;5;67m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]+/)) {
          line = substr(line, 1, RSTART - 1) "\033[38;5;180m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        print line
      }
    '
    return ${pipestatus[1]}
  fi
  if [[ "$1" == "annotate" || "$1" == "blame" || "$1" == "praise" ]]; then
    local subcommand=$1
    shift
    command fossil "$subcommand" "$@" | awk '
      {
        line = $0
        if (match(line, /^[0-9a-fA-F]+/)) {
          line = "\033[38;5;180m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        if (match(line, /[[:space:]][0-9]+:/)) {
          line = substr(line, 1, RSTART - 1) "\033[2m" substr(line, RSTART, RLENGTH) "\033[0m" substr(line, RSTART + RLENGTH)
        }
        print line
      }
    '
    return ${pipestatus[1]}
  fi
  command fossil "$@"
}
