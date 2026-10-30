#!/usr/bin/env python3
"""Prepare generated Android runners for C Brasil's Flutter build."""
import re
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

# This app and its current plugins contain no Android C/C++ targets. Flutter's
# generated NDK pin makes Gradle download a large, unused SDK package and has
# failed on hosted runners, so let Gradle use the installed toolchain if needed.
gradle_files = [
    Path("android/app/build.gradle.kts"),
    Path("android/app/build.gradle"),
]
gradle = next((path for path in gradle_files if path.exists()), None)
if gradle is None:
    raise SystemExit("Generated Android app Gradle file not found.")

gradle_text = gradle.read_text(encoding="utf-8")
cleaned, removed = re.subn(
    r"(?m)^[ \t]*ndkVersion\s*(?:=\s*)?flutter\.ndkVersion[ \t]*\r?\n?",
    "",
    gradle_text,
)
if removed:
    gradle.write_text(cleaned, encoding="utf-8")
