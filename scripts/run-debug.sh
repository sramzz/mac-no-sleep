#!/usr/bin/env bash
set -euo pipefail

echo "=== Building Prevent Sleep (Debug Configuration) ==="
xcodegen generate

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project PreventSleep.xcodeproj \
  -scheme PreventSleep \
  -configuration Debug \
  build

BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "PreventSleep.app" -path "*/Debug/*" 2>/dev/null | head -n 1)

if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    echo "Error: Could not find built PreventSleep.app in DerivedData"
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

echo "Registering with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$BUILT_APP"

echo "Terminating any existing instance..."
killall PreventSleep 2>/dev/null || true

echo "=== Launching in foreground (Debug Mode) ==="
echo "Press Ctrl+C to stop."
exec "$BUILT_APP/Contents/MacOS/PreventSleep" "$@"
