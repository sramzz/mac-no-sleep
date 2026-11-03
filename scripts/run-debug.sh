#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/build/DerivedData"

echo "=== Building Prevent Sleep (Debug Configuration) ==="
cd "$PROJECT_DIR"
xcodegen generate

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project PreventSleep.xcodeproj \
  -scheme PreventSleep \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Debug/PreventSleep.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Could not find built PreventSleep.app at $BUILT_APP"
    exit 1
fi

echo "Signing helper, dynamic libraries, and debug bundle..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY="-"
fi
echo "Using code signing identity: $SIGNING_IDENTITY"
find "$BUILT_APP/Contents/MacOS" -name "*.dylib" -exec codesign -s "$SIGNING_IDENTITY" -o runtime --force {} + 2>/dev/null || true
if [ -d "$BUILT_APP/Contents/Frameworks" ]; then
    find "$BUILT_APP/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm +111 \) -exec codesign -s "$SIGNING_IDENTITY" -o runtime --force {} + 2>/dev/null || true
fi
if [ -f "$BUILT_APP/Contents/MacOS/com.sramzz.mac-no-sleep.helper" ]; then
    codesign -s "$SIGNING_IDENTITY" -o runtime --force -i "com.sramzz.mac-no-sleep.helper" "$BUILT_APP/Contents/MacOS/com.sramzz.mac-no-sleep.helper"
fi
codesign -s "$SIGNING_IDENTITY" -o runtime --force "$BUILT_APP"

echo "Installing to /Applications/PreventSleep.app..."
rm -rf /Applications/PreventSleep.app
cp -R "$BUILT_APP" /Applications/
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted /Applications/PreventSleep.app

echo "Terminating any existing instance..."
killall PreventSleep 2>/dev/null || true

echo "=== Launching in foreground (Debug Mode) ==="
echo "Press Ctrl+C to stop."
exec /Applications/PreventSleep.app/Contents/MacOS/PreventSleep "$@"
