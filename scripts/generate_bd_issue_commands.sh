#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
MANIFEST="${2:-${ROOT_DIR}/plans/inventory/go_port_inventory.tsv}"
ISSUE_TYPE="${3:-task}"
PRIORITY="${4:-2}"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Missing manifest: ${MANIFEST}" >&2
  exit 1
fi

awk -F '\t' -v issue_type="${ISSUE_TYPE}" -v priority="${PRIORITY}" '
/^#/ || NF==0 { next }
{
  id=$1
  kind=$2
  status=$3

  if (status == "missing" || status == "in_progress") {
    split(id, parts, "::")
    file=parts[1]
    symbol=parts[3]
    gsub(/"/, "\\\"", file)
    gsub(/"/, "\\\"", symbol)
    printf("bd create \"Port %s %s (%s)\" --type %s --priority %s\n", kind, symbol, file, issue_type, priority)
  }
}
' "${MANIFEST}"
