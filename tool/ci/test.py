#!/usr/bin/env python3
"""Roda `flutter test` e publica falhas como anotações legíveis do GitHub.

O relatório JSON do `flutter test` é transformado em um resumo curto, e cada
teste que falhar vira uma anotação `::error` com a mensagem e o rastro.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ARGS = sys.argv[1:]


def escape(value: str) -> str:
    return (
        str(value)
        .replace("%", "%25")
        .replace("\r", " ")
        .replace("\n", " ")
    )


def guess_file(name: str) -> str:
    if "abre" in name or "navega" in name:
        return "test/widget_test.dart"
    if "interpretador" in name or "linguagem" in name:
        return "test/interpreter_test.dart"
    if "app" in name or "executor" in name or "widget" in name:
        return "test/widget_test.dart"
    return "test/conformance_test.dart"


def main() -> int:
    command = ["flutter", "test", "--no-pub", "--reporter", "json", *ARGS]
    process = subprocess.run(command, capture_output=True, text=True, check=False)
    Path("/tmp/flutter-test.jsonl").write_text(process.stdout, encoding="utf-8")

    names: dict[str, str] = {}
    failures: list[tuple[str, str]] = []
    details: dict[str, list[str]] = {}
    prints: list[str] = []
    raw_noise: list[str] = []

    for line in process.stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        try:
            event = json.loads(stripped)
        except json.JSONDecodeError:
            raw_noise.append(stripped)
            continue
        kind = event.get("type")
        if kind == "testStart":
            test = event.get("test") or {}
            names[str(test.get("id"))] = test.get("name", "teste")
        elif kind == "print":
            prints.append(str(event.get("message", "")))
        elif kind == "error":
            name = names.get(str(event.get("testID")), "teste")
            detail = str(event.get("error", "falhou"))
            trace = str(event.get("stackTrace", ""))
            details.setdefault(name, []).append(detail)
            failures.append((name, detail, trace))
        elif kind == "testDone":
            if event.get("result") in {"failure", "error"}:
                name = names.get(str(event.get("testID")), "teste")
                if not any(item[0] == name for item in failures):
                    failures.append(
                        (name, "resultado: " + str(event.get("result")), "")
                    )

    for line in raw_noise:
        print(line)

    for item in prints[-40:]:
        print(f"[print] {item}")

    for name, detail, trace in failures:
        snippet = " | ".join(details.get(name, [detail])[-3:])
        for trace_line in trace.splitlines():
            if trace_line.startswith("test/"):
                snippet = f"{snippet} ({trace_line.strip()})"
                break
        if len(snippet) > 1500:
            snippet = f"{snippet[:500]} … {snippet[-900:]}"

        print(
            f"::error file={guess_file(name)},title=Teste falhou: {escape(name)}"
            f"::{escape(snippet)}"
        )
        print(f"FALHOU: {name}\n  {snippet}")

    if failures:
        detailed = subprocess.run(
            ["flutter", "test", "--no-pub", "--reporter", "expanded", *ARGS],
            capture_output=True,
            text=True,
            check=False,
        )
        expanded = f"{detailed.stdout}\n{detailed.stderr}".splitlines()
        Path("/tmp/flutter-test-expanded.txt").write_text(
            "\n".join(expanded), encoding="utf-8"
        )
        emitted = 0
        for index, line in enumerate(expanded):
            if "EXCEPTION CAUGHT" not in line or emitted >= 3:
                continue
            window = [item.strip() for item in expanded[index:index + 12] if item.strip()]
            print(f"::error title=Exceção no teste::{escape(chr(10).join(window))[:1800]}")
            emitted += 1
        if emitted == 0:
            tail = [item.strip() for item in expanded[-40:] if item.strip()]
            print(f"::error title=Fim do log de teste::{escape(chr(10).join(tail))[:1800]}")

    print(f"flutter test: {len(names)} teste(s), {len(failures)} falha(s).")
    if process.returncode != 0:
        if not failures:
            print(process.stderr[-4000:])
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
