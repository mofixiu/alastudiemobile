#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

dark_android="android/app/src/main/res/drawable-night-xxxhdpi/launch_wordmark.png"
swift tool/generate_dark_launch_wordmark.swift "$dark_android"

launch_images="ios/Runner/Assets.xcassets/LaunchImage.imageset"
sips -z 87 280 "$dark_android" --out "$launch_images/LaunchImage-dark.png" >/dev/null
sips -z 174 560 "$dark_android" --out "$launch_images/LaunchImage-dark@2x.png" >/dev/null
sips -z 261 840 "$dark_android" --out "$launch_images/LaunchImage-dark@3x.png" >/dev/null

echo "Generated dark appearance assets for iOS and Android launch screens."
