#!/bin/zsh

# System-wide macOS resource monitor. It deliberately only observes and notifies;
# it never kills or suspends a process.
set -u

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin
INTERVAL=${NEO_RESOURCE_INTERVAL:-15}
CPU_THRESHOLD=${NEO_RESOURCE_CPU_THRESHOLD:-80}
MEMORY_FREE_THRESHOLD=${NEO_RESOURCE_MEMORY_FREE_THRESHOLD:-10}
SAMPLES_REQUIRED=${NEO_RESOURCE_SAMPLES_REQUIRED:-3}

notify() {
  local body="$1"
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "Mac resource alert" -message "$body" >/dev/null 2>&1 || true
    return
  fi

  body=${body//\\/\\\\}
  body=${body//\"/\\\"}
  /usr/bin/osascript -e "display notification \"$body\" with title \"Mac resource alert\"" >/dev/null 2>&1 || true
}

hot_processes() {
  /bin/ps -axo pid=,comm=,%cpu=,etime=,command= 2>/dev/null |
    /usr/bin/awk -v threshold="$CPU_THRESHOLD" '$3 + 0 >= threshold { print $3 "\t" $1 "\t" $2 "\t" $4 }' |
    /usr/bin/sort -nr -k1,1 |
    /usr/bin/head -n 3 |
    /usr/bin/awk -F '\t' '{ printf "%s (pid %s, %s%% CPU)", $3, $2, $1; if (NR < 3) printf "; " }'
}

memory_pressure_summary() {
  local free_percent
  free_percent=$(/usr/bin/memory_pressure -Q 2>/dev/null |
    /usr/bin/awk -F ': ' '/System-wide memory free percentage/ { gsub("%", "", $2); print $2; exit }')
  if [[ "$free_percent" =~ '^[0-9]+$' ]] && (( free_percent < MEMORY_FREE_THRESHOLD )); then
    print -r -- "memory pressure (free ${free_percent}%)"
  fi
}

samples=0
alerted=0
trap 'exit 0' INT TERM HUP

while true; do
  hot="$(hot_processes)"
  memory="$(memory_pressure_summary)"
  if [[ -n "$hot" || -n "$memory" ]]; then
    (( samples++ ))
    if (( samples >= SAMPLES_REQUIRED && alerted == 0 )); then
      local_message="$hot"
      [[ -n "$memory" ]] && local_message="${local_message:+$local_message; }$memory"
      notify "$local_message"
      alerted=1
    fi
  else
    samples=0
    alerted=0
  fi
  /bin/sleep "$INTERVAL"
done
