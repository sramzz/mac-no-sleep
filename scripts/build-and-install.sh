#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/build/DerivedData"

echo "=== Building Prevent Sleep for macOS Tahoe ==="
cd "$PROJECT_DIR"
xcodegen generate

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project PreventSleep.xcodeproj \
  -scheme PreventSleep \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/PreventSleep.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Could not find built PreventSleep.app at $BUILT_APP"
    exit 1
fi

echo "Built app at: $BUILT_APP"
SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}' || true)
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY="-"
fi
echo "Using code signing identity: $SIGNING_IDENTITY"
find "$BUILT_APP/Contents/MacOS" -name "*.dylib" -exec codesign -s "$SIGNING_IDENTITY" -o runtime --force {} + 2>/dev/null || true
if [ -d "$BUILT_APP/Contents/Frameworks" ]; then
    find "$BUILT_APP/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm +111 \) -exec codesign -s "$SIGNING_IDENTITY" -o runtime --force {} + 2>/dev/null || true
fi
if [ -f "$BUILT_APP/Contents/MacOS/com.preventsleep.helper" ]; then
    codesign -s "$SIGNING_IDENTITY" -o runtime --force -i "com.preventsleep.helper" "$BUILT_APP/Contents/MacOS/com.preventsleep.helper"
fi
codesign -s "$SIGNING_IDENTITY" -o runtime --force "$BUILT_APP"

echo "Verifying code signatures..."
codesign --verify --deep --strict "$BUILT_APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
"$LSREGISTER" -u "$PROJECT_DIR/build/dmg_staging/PreventSleep.app" 2>/dev/null || true

echo "=== Build and Verification Complete ==="
if [[ "${1:-}" == "--install" || "${1:-}" == "-i" ]]; then
    echo "Installing to /Applications..."
    killall PreventSleep 2>/dev/null || true
    if [ -x "/Applications/PreventSleep.app/Contents/MacOS/PreventSleep" ]; then
        /Applications/PreventSleep.app/Contents/MacOS/PreventSleep --unregister 2>/dev/null || true
        sleep 1
    fi
    rm -rf /Applications/PreventSleep.app
    cp -R "$BUILT_APP" /Applications/
    "$LSREGISTER" -f -R -trusted /Applications/PreventSleep.app
    echo "Installed to /Applications/PreventSleep.app"
else
    echo "To install to /Applications, run:"
    echo "  ./scripts/build-and-install.sh --install"
    echo "or:"
    echo "  cp -R \"$BUILT_APP\" /Applications/"
fi
