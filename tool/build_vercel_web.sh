#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Vercel does not provide a Flutter SDK in its default builder. Keep the SDK
# under Vercel's build cache so subsequent deploys can reuse the checkout.
FLUTTER_ROOT="${FLUTTER_ROOT:-$ROOT_DIR/.vercel/cache/flutter}"
if ! command -v flutter >/dev/null 2>&1; then
  if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
    mkdir -p "$(dirname "$FLUTTER_ROOT")"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
  fi
  export PATH="$FLUTTER_ROOT/bin:$PATH"
fi

flutter config --no-analytics
flutter config --enable-web
flutter --version
flutter pub get

UPSTREAM_SHA="${CBR_UPSTREAM_COMMIT:-}"
if [[ -z "$UPSTREAM_SHA" ]]; then
  UPSTREAM_SHA="$(git ls-remote https://github.com/vorgweb/C-Brasil.git refs/heads/main 2>/dev/null | cut -f1 || true)"
fi
UPSTREAM_SHA="${UPSTREAM_SHA:-${VERCEL_GIT_COMMIT_SHA:-unknown}}"

flutter build web --release \
  --base-href / \
  --dart-define="CBR_UPSTREAM_COMMIT=$UPSTREAM_SHA"
