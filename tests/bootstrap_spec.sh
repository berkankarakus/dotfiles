#!/usr/bin/env bash
set -euo pipefail

for script in bootstrap-macos.sh bootstrap-macos-csharp.sh; do
  bash -n "$script"
  grep -Fq 'after/queries/mssql' "$script"
done

printf 'bootstrap_spec: ok\n'
