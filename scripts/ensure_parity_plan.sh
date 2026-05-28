#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
SOURCE_PATH="${2:-${PORT_SOURCE_DIR:-}}"
LANGUAGE="${3:-${PORT_LANGUAGE:-go}}"
PARSER="${4:-${PORT_PARSER:-auto}}"
REFRESH="${5:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INV_DIR="${ROOT_DIR}/plans/inventory"
PORT_MANIFEST="${INV_DIR}/${LANGUAGE}_port_inventory.tsv"
SOURCE_MANIFEST="${INV_DIR}/${LANGUAGE}_source_parity.tsv"
TEST_MANIFEST="${INV_DIR}/${LANGUAGE}_test_parity.tsv"

mkdir -p "${INV_DIR}"

# SAFETY CHECK: Never allow overwriting port_inventory via ensure_parity_plan
# Port inventory is a curated working ledger - always preserve it
if [[ "${PORT_FORCE_OVERWRITE:-0}" == "1" ]]; then
  echo "WARNING: PORT_FORCE_OVERWRITE=1 detected. This script will NOT overwrite port_inventory."
  echo "Port inventory is a curated working ledger. Use check_port_inventory.sh for drift checks."
  echo "To reset port_inventory (DESTRUCTIVE), run generate_port_inventory.sh directly."
  # Clear the force flag for this run - we only allow it for source/test manifests
  export PORT_FORCE_OVERWRITE=0
fi

run_generate() {
  local script="$1"
  local out="$2"
  shift 2
  "${SCRIPT_DIR}/${script}" "${ROOT_DIR}" "${out}" "${SOURCE_PATH}" "${LANGUAGE}" "$@" >/dev/null
}

# Bootstrap missing manifests; optional refresh for source/test snapshots.
[[ -f "${PORT_MANIFEST}" ]] || run_generate generate_port_inventory.sh "${PORT_MANIFEST}"
if [[ ! -f "${SOURCE_MANIFEST}" || "${REFRESH}" == "1" ]]; then
  if [[ "${REFRESH}" == "1" ]]; then
    run_generate generate_source_parity_manifest.sh "${SOURCE_MANIFEST}" "${PORT_SOURCE_NOTES_OVERRIDES:-}" 1
  else
    run_generate generate_source_parity_manifest.sh "${SOURCE_MANIFEST}" "${PORT_SOURCE_NOTES_OVERRIDES:-}"
  fi
fi
if [[ ! -f "${TEST_MANIFEST}" || "${REFRESH}" == "1" ]]; then
  if [[ "${REFRESH}" == "1" ]]; then
    run_generate generate_test_parity_manifest.sh "${TEST_MANIFEST}" 1
  else
    run_generate generate_test_parity_manifest.sh "${TEST_MANIFEST}"
  fi
fi

"${SCRIPT_DIR}/check_port_inventory.sh" "${ROOT_DIR}" "${PORT_MANIFEST}" "${SOURCE_PATH}" "${LANGUAGE}"
"${SCRIPT_DIR}/check_source_parity.sh" "${ROOT_DIR}" "${SOURCE_MANIFEST}" "${SOURCE_PATH}" "${LANGUAGE}"
"${SCRIPT_DIR}/check_test_parity.sh" "${ROOT_DIR}" "${TEST_MANIFEST}" "${SOURCE_PATH}" "${LANGUAGE}"

echo "Parity plan ready and validated for language=${LANGUAGE}."
echo "Manifests:"
echo "  - ${PORT_MANIFEST}"
echo "  - ${SOURCE_MANIFEST}"
echo "  - ${TEST_MANIFEST}"
