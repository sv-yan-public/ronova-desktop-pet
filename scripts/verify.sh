#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./build.sh
xcrun swiftc -module-cache-path .build/module-cache -framework AppKit -framework SpriteKit Sources/WalkingRig.swift Sources/WalkingUpperBody.swift scripts/check-upper-body.swift -o .build/check-upper-body
.build/check-upper-body
out="$PWD/.build/verification"
mkdir -p "$out"
bin="$PWD/dist/Ronova.app/Contents/MacOS/RonovaImage"
"$bin" --qa --qa-status "$out/status.json"
"$bin" --qa --auto --walk --reference "$out"
xcrun swift scripts/check-results.swift "$out/status.json" "$out/checks.json"
codesign --verify --deep --strict 'dist/Ronova.app'
