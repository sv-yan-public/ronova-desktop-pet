#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/dist/若娜瓦图片版.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build/module-cache"
xcrun swiftc -O -module-cache-path "$PWD/.build/module-cache" -framework AppKit -framework SpriteKit -framework AVFoundation Sources/main.swift -o "$APP/Contents/MacOS/RonovaImage"
cp -R Assets "$APP/Contents/Resources/"
cp Assets/AppIcon.icns "$APP/Contents/Resources/RonovaPortrait.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIconFile</key><string>RonovaPortrait.icns</string><key>CFBundleExecutable</key><string>RonovaImage</string><key>CFBundleIdentifier</key><string>local.sv.ronova.imagepet</string><key>CFBundleName</key><string>若娜瓦图片版</string><key>CFBundleDisplayName</key><string>若娜瓦图片版</string><key>CFBundleVersion</key><string>15</string><key>CFBundleShortVersionString</key><string>1.2.2</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>LSUIElement</key><true/><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
