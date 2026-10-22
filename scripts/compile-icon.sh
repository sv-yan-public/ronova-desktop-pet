#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
out="$PWD/.build/compiled-icon"
mkdir -p "$out"
if xcrun --find actool >/dev/null 2>&1; then
  xcrun actool Icon/Ronova.icon --compile "$out" --platform macosx --minimum-deployment-target 14.0 --app-icon Ronova --include-all-app-icons --output-partial-info-plist "$out/partial.plist"
  shasum -a 256 Icon/Ronova.icon/icon.json Icon/Ronova.icon/Assets/Portrait.png > "$out/source.sha256"
else
  shasum -a 256 -c Assets/Compiled/source.sha256
  cp Assets/Compiled/Assets.car Assets/Compiled/Ronova.icns "$out/"
fi
[[ -s "$out/Assets.car" && -s "$out/Ronova.icns" ]]
