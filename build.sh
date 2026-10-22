#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/dist/ronova.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build/module-cache"
./scripts/compile-icon.sh
xcrun swiftc -O -module-cache-path "$PWD/.build/module-cache" -framework AppKit -framework SpriteKit -framework AVFoundation Sources/main.swift -o "$APP/Contents/MacOS/RonovaImage"
cp -R Assets "$APP/Contents/Resources/"
cp .build/compiled-icon/Assets.car "$APP/Contents/Resources/Assets.car"
cp .build/compiled-icon/Ronova.icns "$APP/Contents/Resources/RonovaIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIconName</key><string>Ronova</string><key>CFBundleIconFile</key><string>RonovaIcon.icns</string><key>CFBundleExecutable</key><string>RonovaImage</string><key>CFBundleIdentifier</key><string>local.sv.ronova.imagepet</string><key>CFBundleName</key><string>ronova</string><key>CFBundleDisplayName</key><string>ronova</string><key>CFBundleVersion</key><string>18</string><key>CFBundleShortVersionString</key><string>1.2.5</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>LSUIElement</key><true/><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
xattr -cr "$APP"
rm -f "$APP/"$'Icon\r'
codesign --force --deep --sign - "$APP"
