#!/usr/bin/env python3
"""Gera todos os ícones do C Brasil a partir da logo original.

Entrada: a logo quadrada (padrão `assets/branding/logo-original.png`).
Saída: ícones de web, Android, iOS, macOS, Windows, Linux e o asset usado
dentro do app.

Nada de dependências externas: decodifica e escreve PNG/ICO/ICNS em Python
puro, o que mantém o build reproduzível em qualquer máquina com Python 3.
"""

from __future__ import annotations

import json
import math
import os
import struct
import sys
import zlib
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path(os.environ.get("CBR_LOGO", ROOT / "assets/branding/logo-original.png"))

TILE_TOP = (14, 42, 56)
TILE_BOTTOM = (6, 20, 28)
GLOW = (25, 195, 125)


# --------------------------------------------------------------------- PNG

def read_png(path: Path) -> tuple[int, int, bytearray]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} não é um PNG")
    pos = 8
    idat = bytearray()
    width = height = bit_depth = color_type = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if bit_depth != 8 or color_type != 6 or interlace != 0:
                raise SystemExit("a logo precisa ser PNG RGBA de 8 bits sem entrelaçamento")
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + length

    raw = zlib.decompress(bytes(idat))
    stride = width * 4
    pixels = bytearray(width * height * 4)
    previous = bytearray(stride)
    offset = 0
    for row in range(height):
        filter_type = raw[offset]
        offset += 1
        line = bytearray(raw[offset : offset + stride])
        offset += stride
        if filter_type == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 0xFF
        elif filter_type == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == 3:
            for i in range(stride):
                left = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = previous[i]
                c = previous[i - 4] if i >= 4 else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                predictor = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + predictor) & 0xFF
        pixels[row * stride : (row + 1) * stride] = line
        previous = line
    return width, height, pixels


def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    stride = width * 4
    raw = bytearray()
    for row in range(height):
        raw.append(0)
        raw += pixels[row * stride : (row + 1) * stride]

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    output = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(output)


# ------------------------------------------------------------------ imagem

def make_corners_transparent(width: int, height: int, pixels: bytearray) -> None:
    """Remove o fundo branco ao redor do hexágono, preservando o branco interno."""
    def is_white(index: int) -> bool:
        r, g, b, a = pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3]
        return a > 0 and r > 242 and g > 242 and b > 242

    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        index = y * width + x
        if visited[index]:
            continue
        visited[index] = 1
        if not is_white(index * 4):
            continue
        pixels[index * 4 + 3] = 0
        pixels[index * 4] = 0
        pixels[index * 4 + 1] = 0
        pixels[index * 4 + 2] = 0
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))


def resize(width: int, height: int, pixels: bytearray, target: int) -> bytearray:
    """Redimensiona com média de área (box filter) em alfa pré-multiplicado."""
    if width == target and height == target:
        return bytearray(pixels)
    out = bytearray(target * target * 4)
    scale = width / target
    for ty in range(target):
        y0 = int(ty * scale)
        y1 = max(y0 + 1, int((ty + 1) * scale))
        for tx in range(target):
            x0 = int(tx * scale)
            x1 = max(x0 + 1, int((tx + 1) * scale))
            r = g = b = a = 0.0
            count = 0
            for y in range(y0, y1):
                row = y * width
                for x in range(x0, x1):
                    i = (row + x) * 4
                    alpha = pixels[i + 3] / 255.0
                    r += pixels[i] * alpha
                    g += pixels[i + 1] * alpha
                    b += pixels[i + 2] * alpha
                    a += alpha
                    count += 1
            if count == 0:
                continue
            alpha = a / count
            o = (ty * target + tx) * 4
            if alpha > 0:
                out[o] = min(255, int(r / count / alpha))
                out[o + 1] = min(255, int(g / count / alpha))
                out[o + 2] = min(255, int(b / count / alpha))
            out[o + 3] = min(255, int(round(alpha * 255)))
    return out


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def rounded_tile(size: int, radius_ratio: float = 0.23) -> bytearray:
    """Fundo escuro com gradiente suave e brilho verde no centro."""
    pixels = bytearray(size * size * 4)
    radius = size * radius_ratio
    cx = cy = size / 2.0
    for y in range(size):
        for x in range(size):
            px, py = x + 0.5, y + 0.5
            dx = max(abs(px - cx) - (size / 2 - radius), 0)
            dy = max(abs(py - cy) - (size / 2 - radius), 0)
            distance = math.hypot(dx, dy)
            coverage = 0.0
            if distance <= radius - 1:
                coverage = 1.0
            elif distance < radius:
                coverage = radius - distance
            if coverage <= 0:
                continue
            color = _mix(TILE_TOP, TILE_BOTTOM, (px + py) / (2 * size))
            glow = max(0.0, 1.0 - math.hypot(px - cx, py - cy) / (size * 0.62))
            color = _mix(color, GLOW, glow * 0.16)
            o = (y * size + x) * 4
            pixels[o] = color[0]
            pixels[o + 1] = color[1]
            pixels[o + 2] = color[2]
            pixels[o + 3] = int(round(255 * min(1.0, coverage)))
    return pixels


def compose_icon(logo: bytearray, logo_size: int, size: int, padding: float = 0.11) -> bytearray:
    tile = rounded_tile(size)
    inner = int(size * (1 - 2 * padding))
    scaled = resize(logo_size, logo_size, logo, inner)
    offset = (size - inner) // 2
    for y in range(inner):
        for x in range(inner):
            i = (y * inner + x) * 4
            alpha = scaled[i + 3] / 255.0
            if alpha <= 0:
                continue
            o = ((y + offset) * size + (x + offset)) * 4
            base_alpha = tile[o + 3] / 255.0
            out_alpha = alpha + base_alpha * (1 - alpha)
            if out_alpha <= 0:
                continue
            for channel in range(3):
                tile[o + channel] = int(
                    (scaled[i + channel] * alpha
                     + tile[o + channel] * base_alpha * (1 - alpha))
                    / out_alpha
                )
            tile[o + 3] = int(round(out_alpha * 255))
    return tile


def png_bytes(width: int, height: int, pixels: bytearray) -> bytes:
    path = ROOT / "build" / "icons-tmp.png"
    write_png(path, width, height, pixels)
    data = path.read_bytes()
    path.unlink()
    return data


# ------------------------------------------------------------- contêineres

def write_ico(path: Path, entries: list[tuple[int, bytes]]) -> None:
    header = struct.pack("<HHH", 0, 1, len(entries))
    directory = b""
    payload = b""
    offset = 6 + 16 * len(entries)
    for size, data in entries:
        dimension = 0 if size >= 256 else size
        directory += struct.pack(
            "<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(data), offset
        )
        offset += len(data)
        payload += data
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + directory + payload)


def write_icns(path: Path, entries: list[tuple[bytes, bytes]]) -> None:
    body = b"".join(kind + struct.pack(">I", len(data) + 8) + data for kind, data in entries)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


# ------------------------------------------------------------------- main

def main() -> int:
    if not SOURCE.exists():
        raise SystemExit(
            f"logo não encontrada em {SOURCE}. Use CBR_LOGO=/caminho/logo.png"
        )
    width, height, pixels = read_png(SOURCE)
    if width != height:
        raise SystemExit("a logo precisa ser quadrada")
    make_corners_transparent(width, height, pixels)

    branding = ROOT / "assets" / "branding"
    write_png(branding / "logo.png", width, height, pixels)

    # Ícone do app em PNG transparente (usado em janelas e como fallback).
    write_png(
        branding / "logo-mark.png",
        512,
        512,
        resize(width, height, pixels, 512),
    )

    cache: dict[int, bytearray] = {}

    def icon(size: int) -> bytearray:
        if size not in cache:
            cache[size] = compose_icon(pixels, width, size)
        return cache[size]

    # Web
    web = ROOT / "web"
    write_png(web / "favicon.png", 32, 32, icon(32))
    write_png(web / "icons" / "Icon-192.png", 192, 192, icon(192))
    write_png(web / "icons" / "Icon-512.png", 512, 512, icon(512))
    write_png(web / "icons" / "Icon-maskable-192.png", 192, 192, compose_icon(pixels, width, 192, padding=0.19))
    write_png(web / "icons" / "Icon-maskable-512.png", 512, 512, compose_icon(pixels, width, 512, padding=0.19))

    # Android
    android = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        write_png(android / folder / "ic_launcher.png", size, size, icon(size))

    # iOS
    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_icons = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, size in ios_icons.items():
        write_png(ios / name, size, size, icon(size))

    # macOS
    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    macos_icons = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for name, size in macos_icons.items():
        write_png(macos / name, size, size, icon(size))

    # Windows
    ico_entries = [(size, png_bytes(size, size, icon(size))) for size in (16, 24, 32, 48, 64, 128, 256)]
    write_ico(ROOT / "windows" / "runner" / "resources" / "app_icon.ico", ico_entries)

    # macOS .icns (usado por empacotadores e pelo Finder)
    icns_entries = [
        (b"icp4", png_bytes(16, 16, icon(16))),
        (b"icp5", png_bytes(32, 32, icon(32))),
        (b"icp6", png_bytes(64, 64, icon(64))),
        (b"ic07", png_bytes(128, 128, icon(128))),
        (b"ic08", png_bytes(256, 256, icon(256))),
        (b"ic09", png_bytes(512, 512, icon(512))),
        (b"ic10", png_bytes(1024, 1024, icon(1024) if 1024 in cache else compose_icon(pixels, width, 1024))),
    ]
    write_icns(branding / "cbr.icns", icns_entries)

    # Linux (usado por pacotes .deb e atalhos .desktop)
    write_png(branding / "cbr-linux-256.png", 256, 256, icon(256))
    write_png(branding / "cbr-linux-512.png", 512, 512, icon(512))

    manifest = {
        "logo": "assets/branding/logo.png",
        "generatedFrom": str(SOURCE.relative_to(ROOT)) if SOURCE.is_relative_to(ROOT) else str(SOURCE),
        "sizes": sorted(cache.keys()),
    }
    (branding / "icons.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    total = len(list(branding.glob("*")))
    print(f"Ícones gerados a partir de {SOURCE.name} ({total} arquivos de marca).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
