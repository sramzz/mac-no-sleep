#!/usr/bin/env bash
set -euo pipefail

echo "=== Building Prevent Sleep for macOS Tahoe ==="
xcodegen generate

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project PreventSleep.xcodeproj \
  -scheme PreventSleep \
  -configuration Release \
  build

BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "PreventSleep.app" -path "*/Release/*" 2>/dev/null | head -n 1)

if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    echo "Error: Could not find built PreventSleep.app in DerivedData"
    exit 1
fi

echo "Built app at: $BUILT_APP"
echo "Signing app bundle with ad-hoc signature..."
codesign -s - --force --deep "$BUILT_APP"

echo "Verifying code signatures..."
codesign --verify --deep --strict "$BUILT_APP"

echo "=== Build and Verification Complete ==="
echo "To install to /Applications, run:"
echo "  cp -R \"$BUILT_APP\" /Applications/"
