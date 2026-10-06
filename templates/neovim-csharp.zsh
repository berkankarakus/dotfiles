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
  local selection exit_status
  selection=$(fc -rl 1 | awk '{ line = $0; sub(/^[[:space:]]*[0-9]+\\*?[[:space:]]+/, "", line); if (!seen[line]++) print line }' | fzf --height=45% --layout=reverse --border --prompt='History> ' --query="$LBUFFER")
  exit_status=$?
  if (( exit_status != 0 )); then
    zle reset-prompt
    return
  fi
  BUFFER="$selection"
  CURSOR=$#BUFFER
  zle reset-prompt
}
zle -N fzf_history_widget
bindkey '^R' fzf_history_widget

# `dotnet run` uses Release by default here. Web SDK projects open the launch
# profile's Swagger URL once Kestrel is ready; workers and other project types
# are passed through unchanged.
dotnet_open_browser_when_ready() {
  local url=$1
  (
    local attempt
    for attempt in {1..90}; do
      if curl -k -sS --max-time 1 -o /dev/null "$url" >/dev/null 2>&1; then
        open "$url"
        return
      fi
      sleep 1
    done
  ) &!
}

dotnet() {
  local command_name=$1
  shift || return

  if [[ "$command_name" != "run" ]]; then
    command dotnet "$command_name" "$@"
    return
  fi

  local project_path= launch_profile= argument has_configuration=false no_launch_profile=false
  local -a arguments projects
  arguments=("$@")
  local index=1
  while (( index <= $#arguments )); do
    argument=${arguments[index]}
    case "$argument" in
      --project|-p)
        (( index++ ))
        project_path=${arguments[index]}
        ;;
      --project=*) project_path=${argument#--project=} ;;
      --launch-profile|-lp)
        (( index++ ))
        launch_profile=${arguments[index]}
        ;;
      --launch-profile=*) launch_profile=${argument#--launch-profile=} ;;
      --configuration|-c)
        has_configuration=true
        (( index++ ))
        ;;
      --configuration=*|-c?*) has_configuration=true ;;
      --no-launch-profile) no_launch_profile=true ;;
    esac
    (( index++ ))
  done

  if [[ -z "$project_path" ]]; then
    projects=("$PWD"/*.csproj(N))
    (( $#projects == 1 )) && project_path=$projects[1]
  elif [[ -d "$project_path" ]]; then
    projects=("$project_path"/*.csproj(N))
    (( $#projects == 1 )) && project_path=$projects[1]
  fi

  if [[ -n "$project_path" && -f "$project_path" && "$no_launch_profile" == false ]] \
    && grep -q 'Microsoft.NET.Sdk.Web' "$project_path"; then
    local launch_settings="${project_path:h}/Properties/launchSettings.json"
    if [[ -f "$launch_settings" ]] && grep -q '"launchBrowser"[[:space:]]*:[[:space:]]*true' "$launch_settings"; then
      local application_url launch_url browser_url launch_values
      launch_values=$(awk -v requested_profile="$launch_profile" '
        function braces(line, copy, opens, closes) {
          copy = line
          opens = gsub(/{/, "", copy)
          closes = gsub(/}/, "", copy)
          return opens - closes
        }
        function string_value(line, key, value) {
          value = line
          sub("^[^\\\"]*\\\"" key "\\\"[[:space:]]*:[[:space:]]*\\\"", "", value)
          sub("\\\".*$", "", value)
          return value
        }
        {
          line = $0
          if (!in_profiles) {
            if (line ~ /"profiles"[[:space:]]*:[[:space:]]*{/) {
              in_profiles = 1
              depth = 1
            }
            next
          }

          if (!in_profile && depth == 1 && line ~ /^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*{/) {
            profile_name = line
            sub(/^[[:space:]]*"/, "", profile_name)
            sub(/".*$/, "", profile_name)
            in_profile = 1
            profile_depth = depth + 1
            command_name = application_url = launch_url = ""
            launch_browser = 0
          } else if (in_profile) {
            if (line ~ /"commandName"[[:space:]]*:/) command_name = string_value(line, "commandName")
            if (line ~ /"applicationUrl"[[:space:]]*:/) application_url = string_value(line, "applicationUrl")
            if (line ~ /"launchUrl"[[:space:]]*:/) launch_url = string_value(line, "launchUrl")
            if (line ~ /"launchBrowser"[[:space:]]*:[[:space:]]*true/) launch_browser = 1
          }

          depth += braces(line)
          if (in_profile && depth < profile_depth) {
            if ((requested_profile == "" || profile_name == requested_profile) && command_name == "Project" && launch_browser && application_url != "") {
              print application_url "\t" launch_url
              exit
            }
            in_profile = 0
          }
        }
      ' "$launch_settings")
      IFS=$'\t' read -r application_url launch_url <<< "$launch_values"
      if [[ -n "$application_url" ]]; then
        browser_url="${application_url%%;*}"
        browser_url="${browser_url%/}/${launch_url:-swagger}"
        dotnet_open_browser_when_ready "$browser_url"
      fi
    fi
  fi

  if [[ "$has_configuration" == false ]]; then
    command dotnet run --configuration Release "$@"
  else
    command dotnet run "$@"
  fi
}

# Hide whitespace-only changes from `git diff`, but make them visible as a
# concise notice so they cannot go unnoticed. This applies in every repository.
git() {
  if [[ "$1" != "diff" ]]; then
    command git "$@"
    return
  fi

  shift
  command git diff --ignore-all-space "$@"
  local diff_status=$?
  (( diff_status > 1 )) && return "$diff_status"

  command git diff --ignore-all-space --quiet "$@"
  local meaningful_status=$?
  if (( meaningful_status == 0 )); then
    command git diff --quiet "$@"
    if (( $? == 1 )); then
      print -P '\n%F{yellow}Not: yalnızca whitespace farkları var.%f'
    fi
  fi

  return "$diff_status"
}

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

# Git dalını yalnızca bir Git çalışma ağacındayken prompt'ta göster.
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' formats ' %F{110}[%b%c%u]%f'

prompt_git_sync() {
  PROMPT_GIT_SYNC=
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

  local behind ahead
  read behind ahead <<< "$(command git rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)"
  [[ "$behind" == <-> && "$ahead" == <-> ]] || return

  local -a sync_status
  (( ahead > 0 )) && sync_status+=("↑$ahead")
  (( behind > 0 )) && sync_status+=("↓$behind")
  (( $#sync_status > 0 )) && PROMPT_GIT_SYNC=" %F{180}${(j: :)sync_status}%f"
}

prompt_context() {
  local exit_status=$?
  if (( exit_status == 0 )); then
    PROMPT_FAILURE=
  else
    PROMPT_FAILURE="%F{167}✗ $exit_status%f "
  fi
  vcs_info
  prompt_git_sync
}

precmd_functions=(${precmd_functions:#vcs_info})
precmd_functions=(${precmd_functions:#prompt_context})
precmd_functions+=(prompt_context)
setopt PROMPT_SUBST
PROMPT='${PROMPT_FAILURE}%F{67}%1~%f${vcs_info_msg_0_}${PROMPT_GIT_SYNC} %# '
