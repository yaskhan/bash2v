#!/usr/bin/env bash
set -euo pipefail

script_path="${1:-}"
if [[ -z "${script_path}" ]]; then
    echo "usage: bash_runner.sh <script>" >&2
    exit 1
fi

bash "${script_path}"
