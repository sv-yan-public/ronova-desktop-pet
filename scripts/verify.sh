#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./build.sh
out="$PWD/.build/verification"
mkdir -p "$out"
bin="$PWD/dist/若娜瓦.app/Contents/MacOS/RonovaImage"
"$bin" --qa --qa-status "$out/status.json"
"$bin" --qa --auto --walk --reference "$out"
xcrun swift scripts/check-results.swift "$out/status.json" "$out/checks.json"
codesign --verify --deep --strict 'dist/若娜瓦.app'
