#!/usr/bin/env bash
# Confere se os resultados esperados em test/conformance/expected continuam
# iguais aos do compilador oficial (vorgweb/C-Brasil).
#
# Requer: git, gcc (ou $CC) e acesso ao GitHub.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${CBR_CONFORMANCE_WORK:-$(mktemp -d)}"
UPSTREAM_URL="${CBR_UPSTREAM_URL:-https://github.com/vorgweb/C-Brasil.git}"
CC_BIN="${CC:-gcc}"
UPDATE="${CBR_UPDATE_GOLDENS:-0}"

rm -rf "$WORK_DIR/upstream"
git clone --depth 1 --quiet "$UPSTREAM_URL" "$WORK_DIR/upstream"
UPSTREAM_SHA="$(git -C "$WORK_DIR/upstream" rev-parse HEAD)"
echo "Compilador oficial em $UPSTREAM_SHA"

"$CC_BIN" -std=c11 -O2 "$WORK_DIR/upstream/cbr.c" -lm -o "$WORK_DIR/cbr"

failures=0
checked=0

for source in "$ROOT_DIR"/test/conformance/programs/*.cbr; do
  name="$(basename "$source" .cbr)"
  expected="$ROOT_DIR/test/conformance/expected/$name.out"
  [ -f "$expected" ] || continue

  translated="$WORK_DIR/$name.c"
  binary="$WORK_DIR/$name.bin"
  actual="$WORK_DIR/$name.actual"

  if ! "$WORK_DIR/cbr" "$source" "$translated" > "$WORK_DIR/$name.translate.log" 2>&1; then
    echo "::error title=Conformidade::$name não traduziu com o compilador oficial"
    failures=$((failures + 1))
    continue
  fi
  if ! "$CC_BIN" -std=c11 -O2 "$translated" -lm -o "$binary" 2> "$WORK_DIR/$name.cc.log"; then
    echo "::error title=Conformidade::o C gerado para $name não compilou"
    failures=$((failures + 1))
    continue
  fi
  stdin_file="$ROOT_DIR/test/conformance/programs/$name.stdin"
  if [ -f "$stdin_file" ]; then
    "$binary" < "$stdin_file" > "$actual" 2>&1 || true
  else
    "$binary" > "$actual" 2>&1 || true
  fi

  checked=$((checked + 1))
  if [ "$UPDATE" = "1" ]; then
    cp "$actual" "$expected"
    echo "atualizado: $name"
    continue
  fi
  if ! diff -u "$expected" "$actual" > "$WORK_DIR/$name.diff"; then
    echo "::error title=Conformidade::saída de $name divergiu do compilador oficial"
    echo "--- divergência em $name ---"
    head -40 "$WORK_DIR/$name.diff"
    failures=$((failures + 1))
  fi
done

echo "Programas conferidos: $checked; divergências: $failures"
[ "$failures" -eq 0 ]
