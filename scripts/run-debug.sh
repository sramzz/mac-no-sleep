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

echo "Signing helper and debug bundle..."
codesign -s - --force -i "com.sramzz.mac-no-sleep.helper" "$BUILT_APP/Contents/Library/LaunchDaemons/com.sramzz.mac-no-sleep.helper"
codesign -s - --force "$BUILT_APP"

echo "Registering with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$BUILT_APP"

echo "Terminating any existing instance..."
killall PreventSleep 2>/dev/null || true

echo "=== Launching in foreground (Debug Mode) ==="
echo "Press Ctrl+C to stop."
exec "$BUILT_APP/Contents/MacOS/PreventSleep"
