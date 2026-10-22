#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/dist/若娜瓦.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build/module-cache"
xcrun swift -module-cache-path "$PWD/.build/module-cache" scripts/make-icon.swift Assets/AppIcon.png "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o Assets/AppIcon.icns
xcrun swiftc -O -module-cache-path "$PWD/.build/module-cache" -framework AppKit -framework SpriteKit -framework AVFoundation Sources/main.swift -o "$APP/Contents/MacOS/RonovaImage"
cp -R Assets "$APP/Contents/Resources/"
cp Assets/AppIcon.icns "$APP/Contents/Resources/RonovaIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIconFile</key><string>RonovaIcon.icns</string><key>CFBundleExecutable</key><string>RonovaImage</string><key>CFBundleIdentifier</key><string>local.sv.ronova.imagepet</string><key>CFBundleName</key><string>若娜瓦</string><key>CFBundleDisplayName</key><string>若娜瓦</string><key>CFBundleVersion</key><string>16</string><key>CFBundleShortVersionString</key><string>1.2.3</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>LSUIElement</key><true/><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
xattr -cr "$APP"
rm -f "$APP/"$'Icon\r'
codesign --force --deep --sign - "$APP"
