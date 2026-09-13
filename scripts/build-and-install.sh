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
SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY="-"
fi
echo "Using code signing identity: $SIGNING_IDENTITY"
find "$BUILT_APP/Contents/MacOS" -type f \( -name "*.dylib" -o -name "com.sramzz.*" \) -exec codesign -s "$SIGNING_IDENTITY" -o runtime --force {} + 2>/dev/null || true
if [ -d "$BUILT_APP/Contents/Frameworks" ]; then
    find "$BUILT_APP/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm +111 \) -exec codesign -s "$SIGNING_IDENTITY" -o runtime --force {} + 2>/dev/null || true
fi
codesign -s "$SIGNING_IDENTITY" -o runtime --force "$BUILT_APP"

echo "Verifying code signatures..."
codesign --verify --deep --strict "$BUILT_APP"

echo "=== Build and Verification Complete ==="
if [[ "${1:-}" == "--install" || "${1:-}" == "-i" ]]; then
    echo "Installing to /Applications..."
    rm -rf /Applications/PreventSleep.app
    cp -R "$BUILT_APP" /Applications/
    /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted /Applications/PreventSleep.app
    echo "Installed to /Applications/PreventSleep.app"
else
    echo "To install to /Applications, run:"
    echo "  ./scripts/build-and-install.sh --install"
    echo "or:"
    echo "  cp -R \"$BUILT_APP\" /Applications/"
fi
