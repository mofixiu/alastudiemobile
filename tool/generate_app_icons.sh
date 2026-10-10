#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

icon_tmp_dir="$(mktemp -d /private/tmp/alastudie-icons.XXXXXX)"
trap 'rm -rf "$icon_tmp_dir"' EXIT
swift -module-cache-path "$icon_tmp_dir/swift-module-cache" tool/generate_app_icon.swift

sips -s format jpeg -s formatOptions 100 assets/brand/alastudie_app_icon.png \
  --out "$icon_tmp_dir/alastudie_app_icon.jpg" >/dev/null
sips -s format png "$icon_tmp_dir/alastudie_app_icon.jpg" \
  --out "$icon_tmp_dir/alastudie_app_icon_rgb.png" >/dev/null

python3 - "$icon_tmp_dir/alastudie_app_icon_rgb.png" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

root = Path.cwd()
source = Path(sys.argv[1])
appicon = root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
contents = json.loads((appicon / "Contents.json").read_text())

for item in contents["images"]:
    points = float(item["size"].split("x")[0])
    scale = float(item["scale"].removesuffix("x"))
    pixels = round(points * scale)
    destination = appicon / item["filename"]
    subprocess.run(
        ["/usr/bin/sips", "-z", str(pixels), str(pixels), str(source), "--out", str(destination)],
        check=True,
        stdout=subprocess.DEVNULL,
    )

android_sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
for density, pixels in android_sizes.items():
    destination = root / "android/app/src/main/res" / density / "ic_launcher.png"
    subprocess.run(
        ["/usr/bin/sips", "-z", str(pixels), str(pixels), str(source), "--out", str(destination)],
        check=True,
        stdout=subprocess.DEVNULL,
    )

web_icons = {
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
    "web/favicon.png": 32,
}
for relative_path, pixels in web_icons.items():
    subprocess.run(
        ["/usr/bin/sips", "-z", str(pixels), str(pixels), str(source), "--out", str(root / relative_path)],
        check=True,
        stdout=subprocess.DEVNULL,
    )

print(
    f"Generated {len(contents['images'])} iOS icon slots, "
    f"{len(android_sizes)} Android density icons, and {len(web_icons)} web icons."
)
PY
