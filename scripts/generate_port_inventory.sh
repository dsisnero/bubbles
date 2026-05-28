#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
OUT="${2:-}"
SOURCE_PATH="${3:-${PORT_SOURCE_DIR:-}}"
LANGUAGE="${4:-${PORT_LANGUAGE:-go}}"
FORCE_OVERWRITE="${5:-${PORT_FORCE_OVERWRITE:-0}}"
PARSER="${PORT_PARSER:-auto}"

# Example file mapping parameters
EXAMPLE_DIR="${PORT_EXAMPLE_DIR:-}"
EXAMPLE_TARGET="${PORT_EXAMPLE_TARGET:-}"
EXAMPLE_EXT="${PORT_EXAMPLE_EXT:-}"
EXAMPLE_TARGET_EXT="${PORT_EXAMPLE_TARGET_EXT:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

args=(--root "${ROOT_DIR}" --language "${LANGUAGE}" --parser "${PARSER}")
[[ -n "${OUT}" ]] && args+=(--out "${OUT}")
[[ -n "${SOURCE_PATH}" ]] && args+=(--source "${SOURCE_PATH}")
[[ "${FORCE_OVERWRITE}" == "1" ]] && args+=(--force-overwrite)
[[ -n "${EXAMPLE_DIR}" ]] && args+=(--example-dir "${EXAMPLE_DIR}")
[[ -n "${EXAMPLE_TARGET}" ]] && args+=(--example-target "${EXAMPLE_TARGET}")
[[ -n "${EXAMPLE_EXT}" ]] && args+=(--example-ext "${EXAMPLE_EXT}")
[[ -n "${EXAMPLE_TARGET_EXT}" ]] && args+=(--example-target-ext "${EXAMPLE_TARGET_EXT}")

"${SCRIPT_DIR}/generate_port_inventory.rb" "${args[@]}"
