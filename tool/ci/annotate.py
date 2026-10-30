#!/usr/bin/env python3
"""Executa um comando de build e publica as falhas como anotações do GitHub.

O log bruto dos runners não é acessível deste ambiente, então as linhas mais
relevantes do erro viram uma anotação `::error` com o comando que falhou.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

INTERESTING = (
    "Error",
    "error:",
    "ERROR",
    "FAILURE",
    "Exception",
    "failed",
    "Failed",
    "What went wrong",
    "Could not",
    "cannot",
    "Unsupported",
)


def escape(value: str) -> str:
    return value.replace("%", "%25").replace("\r", " ").replace("\n", " ")


def main() -> int:
    command = sys.argv[1:]
    if not command:
        print("uso: annotate.py <comando> [argumentos...]")
        return 2

    process = subprocess.run(command, capture_output=True, text=True, check=False)
    output = f"{process.stdout}\n{process.stderr}"
    Path("/tmp/last-command.log").write_text(output, encoding="utf-8")

    sys.stdout.write(output)
    if process.returncode == 0:
        return 0

    lines = [line for line in output.splitlines() if line.strip()]
    keep = [line for line in lines if any(word in line for word in INTERESTING)]
    chunk = "\n".join((keep or lines)[-40:])
    if len(chunk) > 4000:
        chunk = f"{chunk[:1200]}\n…\n{chunk[-2600:]}"
    print(
        f"::error title=Falha em {' '.join(command)}::{escape(chunk)}",
        flush=True,
    )
    return process.returncode


if __name__ == "__main__":
    sys.exit(main())
