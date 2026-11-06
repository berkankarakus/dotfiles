#!/usr/bin/env bash
set -euo pipefail

run_nvim_test() {
  local test_file=$1
  local state_dir cache_dir status
  state_dir=$(mktemp -d /private/tmp/nvim-test-state.XXXXXX)
  cache_dir=$(mktemp -d /private/tmp/nvim-test-cache.XXXXXX)

  if XDG_STATE_HOME="$state_dir" XDG_CACHE_HOME="$cache_dir" nvim --headless -u init.lua -i NONE -l "$test_file"; then
    status=0
  else
    status=$?
  fi

  rm -rf "$state_dir" "$cache_dir"
  return "$status"
}

# Most specs use per-process state/cache directories and can run independently.
# Keep this configurable so a low-memory machine can fall back to serial runs:
#   NVIM_TEST_JOBS=1 bash tests/run.sh
test_jobs=${NVIM_TEST_JOBS:-4}
if [[ ! "$test_jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo "NVIM_TEST_JOBS must be a positive integer" >&2
  exit 2
fi

run_parallel_tests() {
  local log_dir test_file log_file active=0 failed=0 index
  local -a pids=() logs=()

  if (( test_jobs == 1 )); then
    for test_file in "$@"; do
      run_nvim_test "$test_file"
    done
    return
  fi

  log_dir=$(mktemp -d /private/tmp/nvim-test-logs.XXXXXX)

  wait_batch() {
    for index in "${!pids[@]}"; do
      if ! wait "${pids[index]}"; then
        failed=1
      fi
      cat "${logs[index]}"
    done
    pids=()
    logs=()
    active=0
  }

  for test_file in "$@"; do
    log_file="$log_dir/$(basename "$test_file" .lua).log"
    (run_nvim_test "$test_file") >"$log_file" 2>&1 &
    pids+=("$!")
    logs+=("$log_file")
    ((active += 1))

    if (( active >= test_jobs )); then
      wait_batch
    fi
  done

  if (( active > 0 )); then
    wait_batch
  fi

  rm -rf "$log_dir"
  (( failed == 0 ))
}

session_state=$(mktemp -d /private/tmp/nvim-test-session.XXXXXX)
if XDG_STATE_HOME="$session_state" nvim --clean -u NONE -i NONE --headless -l tests/session_spec.lua; then
  session_status=0
else
  session_status=$?
fi
rm -rf "$session_state"
(( session_status == 0 ))
nvim --clean -u NONE -i NONE --headless -l tests/dotnet_debug_spec.lua

# These tests isolate XDG state/cache and do not touch a shared fixture, so they
# can run in bounded parallel batches. Tests with real processes, fixed paths,
# or SQLite state stay serial below.
run_parallel_tests \
  tests/lazy_startup_spec.lua \
  tests/lazy_csharp_debug_spec.lua \
  tests/lazy_completion_spec.lua \
  tests/plugin_config_smoke_spec.lua \
  tests/options_keymaps_spec.lua \
  tests/virt_column_tail_spec.lua \
  tests/csharp_docstring_spec.lua \
  tests/csharp_new_file_spec.lua \
  tests/ui_spec.lua \
  tests/cmdline_clear_spec.lua \
  tests/terminal_spec.lua \
  tests/telescope_search_spec.lua \
  tests/json_format_spec.lua \
  tests/dotnet_test_spec.lua \
  tests/sql_clause_navigation_spec.lua \
  tests/csharp_statement_navigation_spec.lua \
  tests/unparsed_navigation_spec.lua \
  tests/json_textobjects_spec.lua \
  tests/surround_format_spec.lua \
  tests/lsp_config_spec.lua \
  tests/signature_cycle_spec.lua \
  tests/snippets_spec.lua \
  tests/debug_notification_spec.lua \
  tests/mono_debug_spec.lua \
  tests/call_parens_spec.lua \
  tests/leader_prefix_spec.lua

run_nvim_test tests/frecency_cleanup_spec.lua
run_nvim_test tests/dotnet_build_spec.lua
run_nvim_test tests/sqldeps_spec.lua
run_nvim_test tests/doctor_spec.lua
bash tests/zsh_template_spec.sh
bash tests/bootstrap_spec.sh
