#!/bin/bash
# Usage: bash compose.sh [COMPOSE_ARGS...]; no arguments opens a temporary HOFEM shell.
# Defaults username/UID/GID to the host user and WORKSPACE to the caller's directory.
# Explicit environment values are preserved; Compose arguments are forwarded unchanged.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export LOCAL_UID="${LOCAL_UID:-$(id -u)}"
export LOCAL_GID="${LOCAL_GID:-$(id -g)}"
export LOCAL_USER="${LOCAL_USER:-$(id -un)}"
export WORKSPACE="${WORKSPACE:-$PWD}"

if (( $# == 0 )); then
    set -- run --rm hofem
fi

exec docker compose -f "$repo_dir/compose.yaml" "$@"
