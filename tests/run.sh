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

session_state=$(mktemp -d /private/tmp/nvim-test-session.XXXXXX)
if XDG_STATE_HOME="$session_state" nvim --clean -u NONE -i NONE --headless -l tests/session_spec.lua; then
  session_status=0
else
  session_status=$?
fi
rm -rf "$session_state"
(( session_status == 0 ))
nvim --clean -u NONE -i NONE --headless -l tests/dotnet_debug_spec.lua

run_nvim_test tests/lazy_startup_spec.lua
run_nvim_test tests/lazy_csharp_debug_spec.lua
run_nvim_test tests/lazy_completion_spec.lua
run_nvim_test tests/plugin_config_smoke_spec.lua
run_nvim_test tests/options_keymaps_spec.lua
run_nvim_test tests/csharp_docstring_spec.lua
run_nvim_test tests/csharp_new_file_spec.lua
run_nvim_test tests/ui_spec.lua
run_nvim_test tests/cmdline_clear_spec.lua
run_nvim_test tests/terminal_spec.lua
run_nvim_test tests/frecency_cleanup_spec.lua
run_nvim_test tests/json_format_spec.lua
run_nvim_test tests/dotnet_build_spec.lua
run_nvim_test tests/dotnet_test_spec.lua
run_nvim_test tests/doctor_spec.lua
run_nvim_test tests/sql_clause_navigation_spec.lua
run_nvim_test tests/csharp_statement_navigation_spec.lua
run_nvim_test tests/unparsed_navigation_spec.lua
run_nvim_test tests/json_textobjects_spec.lua
run_nvim_test tests/surround_format_spec.lua
run_nvim_test tests/lsp_config_spec.lua
run_nvim_test tests/snippets_spec.lua
run_nvim_test tests/debug_notification_spec.lua
run_nvim_test tests/mono_debug_spec.lua
run_nvim_test tests/call_parens_spec.lua
run_nvim_test tests/leader_prefix_spec.lua
bash tests/zsh_template_spec.sh
bash tests/bootstrap_spec.sh
