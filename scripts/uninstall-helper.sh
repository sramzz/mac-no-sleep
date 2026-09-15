#!/usr/bin/env bash
set -euo pipefail

echo "=== Prevent Sleep: Manual Helper Uninstall & Reset ==="

echo "Terminating any running PreventSleep app..."
killall PreventSleep 2>/dev/null || true

echo "Unregistering SMAppService daemon via app CLI..."
if [ -f "/Applications/PreventSleep.app/Contents/MacOS/PreventSleep" ]; then
    /Applications/PreventSleep.app/Contents/MacOS/PreventSleep --unregister 2>/dev/null || true
fi

echo "Ensuring system service is booted out..."
sudo launchctl bootout system/com.sramzz.mac-no-sleep.helper 2>/dev/null || true

echo "Restoring system SleepDisabled setting to 0 (Allow Sleep)..."
sudo /usr/bin/pmset disablesleep 0

echo "Verifying power setting:"
/usr/bin/pmset -g | grep -i "SleepDisabled" || true

echo "=== Helper reset and uninstall complete ==="

