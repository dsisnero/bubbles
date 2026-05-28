#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/check_test_parity.sh" "${1:-$(pwd)}" "${2:-}" "${3:-${GO_PORT_SOURCE_DIR:-}}" go
