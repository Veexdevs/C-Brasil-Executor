#!/usr/bin/env python3
"""Roda `dart analyze` e publica as mensagens como anotações do GitHub.

O log bruto do runner não é acessível em todos os ambientes, então cada erro
ou aviso vira uma anotação `::error`/`::warning` com arquivo, linha e coluna.
"""

from __future__ import annotations

import os
import subprocess
import sys
import urllib.parse
from pathlib import Path


def escape(value: str) -> str:
    return (
        value.replace("%", "%25")
        .replace("\r", " ")
        .replace("\n", " ")
    )


def main() -> int:
    process = subprocess.run(
        ["dart", "analyze", "--format=machine", "lib", "test", "tool"],
        capture_output=True,
        text=True,
        check=False,
    )
    output = f"{process.stdout}\n{process.stderr}"
    Path("/tmp/analyzer.txt").write_text(output, encoding="utf-8")

    errors = 0
    warnings = 0
    for line in output.splitlines():
        fields = line.split("|", 7)
        if len(fields) < 8:
            if line.strip():
                print(line)
            continue
        severity, _, _, location, line_no, col, length, message = fields
        if severity not in {"ERROR", "WARNING", "INFO"}:
            print(line)
            continue
        if severity == "INFO":
            continue
        if severity == "ERROR":
            errors += 1
        else:
            warnings += 1
        if location.startswith("file:"):
            location = urllib.parse.urlparse(location).path
        if os.path.isabs(location):
            try:
                location = os.path.relpath(location, os.getcwd())
            except ValueError:
                pass
        kind = "error" if severity == "ERROR" else "warning"
        print(
            f"::{kind} file={location},line={line_no},col={col},"
            f"title={escape(severity)}::{escape(message)}"
        )

    print(f"dart analyze: {errors} erro(s), {warnings} aviso(s).")
    if errors > 0:
        return 1
    if process.returncode != 0 and errors == 0 and warnings == 0:
        print(process.stderr[-4000:])
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
