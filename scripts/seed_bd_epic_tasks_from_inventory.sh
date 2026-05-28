#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
MANIFEST="${2:-${ROOT_DIR}/plans/inventory/go_port_inventory.tsv}"
GROUP_BY="${3:-file}"          # file | package
PRIORITY="${4:-2}"
EPIC_TITLE="${5:-Port Go parity backlog from inventory}"
APPLY="${6:-0}"                # 0 = preview only, 1 = create issues
STATUS_FILTER="${7:-missing,in_progress,partial}"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Missing manifest: ${MANIFEST}" >&2
  exit 1
fi

if [[ "${GROUP_BY}" != "file" && "${GROUP_BY}" != "package" ]]; then
  echo "GROUP_BY must be 'file' or 'package' (got: ${GROUP_BY})" >&2
  exit 1
fi

tmp_groups="$(mktemp)"
trap 'rm -f "${tmp_groups}"' EXIT

awk -F '\t' -v group_by="${GROUP_BY}" -v status_filter="${STATUS_FILTER}" '
function allowed(status,   i, n, arr) {
  n = split(status_filter, arr, ",")
  for (i = 1; i <= n; i++) if (status == arr[i]) return 1
  return 0
}
function dirname(path,   i, c, out) {
  out = ""
  for (i = 1; i <= length(path); i++) {
    c = substr(path, i, 1)
    if (c == "/") out = substr(path, 1, i - 1)
  }
  if (out == "") return "."
  return out
}
/^#/ || NF == 0 { next }
{
  id = $1
  status = $3
  if (!allowed(status)) next

  split(id, parts, "::")
  file = parts[1]
  key = (group_by == "package") ? dirname(file) : file
  group_count[key]++
}
END {
  for (k in group_count) printf("%s\t%d\n", k, group_count[k])
}
' "${MANIFEST}" | sort > "${tmp_groups}"

if [[ ! -s "${tmp_groups}" ]]; then
  echo "No inventory rows matched status filter: ${STATUS_FILTER}" >&2
  exit 0
fi

echo "Planned grouping (${GROUP_BY}) from ${MANIFEST}:"
awk -F '\t' '{ printf("  - %s (%s items)\n", $1, $2) }' "${tmp_groups}"

if [[ "${APPLY}" != "1" ]]; then
  echo
  echo "Preview mode only. Re-run with APPLY=1 (6th arg) to create issues."
  echo "Example:"
  echo "  $(basename "$0") ${ROOT_DIR} ${MANIFEST} ${GROUP_BY} ${PRIORITY} \"${EPIC_TITLE}\" 1 ${STATUS_FILTER}"
  exit 0
fi

# Speed optimization: avoid per-issue auto flush; run one sync at end.
BD_FLAGS=(--silent --no-auto-flush)
if [[ "${BD_NO_DAEMON:-0}" == "1" ]]; then
  BD_FLAGS+=(--no-daemon)
fi

epic_desc="Auto-generated from ${MANIFEST}. Grouped by ${GROUP_BY}. Status filter: ${STATUS_FILTER}."
epic_id="$(bd create "${EPIC_TITLE}" --type epic --priority "${PRIORITY}" --description "${epic_desc}" "${BD_FLAGS[@]}")"
echo "Created epic: ${epic_id}"

total="$(wc -l < "${tmp_groups}" | tr -d ' ')"
i=0
while IFS=$'\t' read -r key count; do
  i=$((i + 1))
  child_title="Port Go parity (${GROUP_BY}: ${key})"
  child_desc="Auto-generated from ${MANIFEST}. Group=${GROUP_BY}:${key}. Items=${count}."

  child_id="$(bd create "${child_title}" --type task --priority "${PRIORITY}" --description "${child_desc}" --parent "${epic_id}" "${BD_FLAGS[@]}")"
  echo "[${i}/${total}] Created child task: ${child_id} (${key}, ${count} items)"
done < "${tmp_groups}"

# One final export/sync after bulk creation.
bd sync

echo "Completed: epic + ${total} child tasks created and synced."
