#!/usr/bin/env bash
# Regenera test/conformance/expected/*.out a partir do compilador oficial.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CBR_UPDATE_GOLDENS=1 bash "$ROOT_DIR/tool/conformance/verify_upstream.sh"
