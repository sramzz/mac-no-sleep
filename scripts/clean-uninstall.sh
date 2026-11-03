#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "🧹  Prevent Sleep: Complete Clean Uninstall & Reset"
echo "============================================================"

# 1. Terminate any running instances
echo "1️⃣  Terminating running instances..."
killall PreventSleep 2>/dev/null || true

# 2. Unregister SMAppService LaunchDaemon
echo "2️⃣  Unregistering privileged LaunchDaemon..."
if [ -f "/Applications/PreventSleep.app/Contents/MacOS/PreventSleep" ]; then
    /Applications/PreventSleep.app/Contents/MacOS/PreventSleep --unregister 2>/dev/null || true
fi
sudo launchctl bootout system/com.sramzz.mac-no-sleep.helper 2>/dev/null || true

# 3. Restore system power setting to normal sleep
echo "3️⃣  Restoring system SleepDisabled setting to 0 (Normal Sleep)..."
sudo /usr/bin/pmset disablesleep 0

# 4. Remove Application bundle
echo "4️⃣  Removing /Applications/PreventSleep.app..."
rm -rf /Applications/PreventSleep.app

# 5. Clear preferences & temporary state
echo "5️⃣  Clearing user preferences..."
defaults delete com.sramzz.mac-no-sleep 2>/dev/null || true
rm -f /tmp/com.sramzz.mac-no-sleep.helper.*

# 6. Unmount any mounted Prevent Sleep disk images
echo "6️⃣  Unmounting any mounted test disk images..."
hdiutil detach "/Volumes/Prevent Sleep" 2>/dev/null || true

# 7. Unregister from LaunchServices
echo "7️⃣  Updating LaunchServices database..."
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u /Applications/PreventSleep.app 2>/dev/null || true

echo ""
echo "============================================================"
echo "✅ CLEAN RESET COMPLETE"
echo "============================================================"
echo "Current system power state:"
/usr/bin/pmset -g | grep -i "SleepDisabled" || echo "SleepDisabled: 0 (Normal sleep allowed)"
echo ""
echo "Your Mac is in a virgin state. You are ready for a fresh install test!"
