#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/generate_test_parity_manifest.sh" "${1:-$(pwd)}" "${2:-}" "${3:-${GO_PORT_SOURCE_DIR:-}}" go
