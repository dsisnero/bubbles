#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
MANIFEST="${2:-${ROOT_DIR}/plans/inventory/go_port_remaining_heuristic.tsv}"
GROUP_BY="${3:-file}"
PRIORITY="${4:-2}"
EPIC_TITLE="${5:-Port Go parity remaining backlog}"
APPLY="${6:-0}"
STATUS_FILTER="${7:-missing,in_progress,partial}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/seed_bd_epic_tasks_from_inventory.sh" \
  "${ROOT_DIR}" "${MANIFEST}" "${GROUP_BY}" "${PRIORITY}" "${EPIC_TITLE}" "${APPLY}" "${STATUS_FILTER}"
