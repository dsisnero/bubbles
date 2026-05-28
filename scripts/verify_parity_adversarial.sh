#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
SOURCE_PATH="${2:-${PORT_SOURCE_DIR:-}}"
LANGUAGE="${3:-${PORT_LANGUAGE:-go}}"
CRYSTAL_SPEC_CMD="${4:-}"
UPSTREAM_TEST_CMD="${5:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/ensure_parity_plan.sh" "${ROOT_DIR}" "${SOURCE_PATH}" "${LANGUAGE}" "${PORT_PARSER:-auto}" 0

for manifest in \
  "${ROOT_DIR}/plans/inventory/${LANGUAGE}_port_inventory.tsv" \
  "${ROOT_DIR}/plans/inventory/${LANGUAGE}_source_parity.tsv" \
  "${ROOT_DIR}/plans/inventory/${LANGUAGE}_test_parity.tsv"; do
  if rg -n "\\t\\t|\\t$" "${manifest}" >/dev/null 2>&1; then
    echo "Manifest contains empty TSV fields (\\t\\t or trailing tab): ${manifest}" >&2
    exit 1
  fi
done

# Strict manifest quality checks.
ruby -e '
  file = ARGV[0]
  rows = File.readlines(file, chomp: true).reject { |l| l.start_with?("#") || l.strip.empty? }
  bad = rows.select do |r|
    c = r.split("\t", -1)
    next true if c.size < 5
    status = c[2]
    refs = c[3]
    (%w[ported partial].include?(status) && refs.to_s.strip.empty?)
  end
  unless bad.empty?
    warn "Invalid port inventory rows in #{file}:"
    bad.each { |r| warn "  - #{r}" }
    exit 1
  end
' "${ROOT_DIR}/plans/inventory/${LANGUAGE}_port_inventory.tsv"

# Detect placeholder tests in Crystal side when applicable.
if [[ -d "${ROOT_DIR}/spec" ]]; then
  if rg --pcre2 -n "^\s*pending(?!\s*(=|<<|\+=|-=|\*=|\/=))(\s|$)|^\s*xit\(|^\s*xdescribe\(|^\s*xcontext\(" "${ROOT_DIR}/spec" "${ROOT_DIR}/src" >/dev/null 2>&1; then
    echo "Found placeholder specs in src/spec. Resolve before parity signoff." >&2
    exit 1
  fi
fi

if [[ -n "${CRYSTAL_SPEC_CMD}" ]]; then
  (cd "${ROOT_DIR}" && eval "${CRYSTAL_SPEC_CMD}")
fi

if [[ -n "${UPSTREAM_TEST_CMD}" ]]; then
  if [[ -n "${SOURCE_PATH}" ]]; then
    if [[ "${SOURCE_PATH}" = /* ]]; then
      (cd "${SOURCE_PATH}" && eval "${UPSTREAM_TEST_CMD}")
    else
      (cd "${ROOT_DIR}/${SOURCE_PATH}" && eval "${UPSTREAM_TEST_CMD}")
    fi
  else
    (cd "${ROOT_DIR}" && eval "${UPSTREAM_TEST_CMD}")
  fi
fi

echo "Adversarial parity verification passed for language=${LANGUAGE}."
