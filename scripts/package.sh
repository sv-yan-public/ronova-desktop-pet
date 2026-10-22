#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./build.sh
app="$PWD/dist/ronova.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
staging=$(mktemp -d "$PWD/.build/installer.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/ronova.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname 'ronova' -srcfolder "$staging" -ov -format UDZO "dist/Ronova-Desktop-Pet-${version}-$(uname -m).dmg"
