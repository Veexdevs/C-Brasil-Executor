#!/usr/bin/env python3
"""Ensure generated Flutter Android builds can check the public upstream API."""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    raise SystemExit(f"Android manifest not found: {manifest}. Run flutter create first.")

text = manifest.read_text(encoding="utf-8")
permission = '<uses-permission android:name="android.permission.INTERNET" />'
if "android.permission.INTERNET" not in text:
    marker = ">"
    start = text.find("<manifest")
    end = text.find(marker, start)
    if start < 0 or end < 0:
        raise SystemExit("Could not find the opening <manifest> tag.")
    text = text[: end + 1] + "\n    " + permission + text[end + 1 :]
    manifest.write_text(text, encoding="utf-8")
