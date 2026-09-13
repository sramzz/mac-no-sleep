#!/usr/bin/env bash
set -euo pipefail

echo "=== Prevent Sleep: Manual Helper Uninstall & Reset ==="
echo "Restoring system SleepDisabled setting to 0 (Allow Sleep)..."
sudo /usr/bin/pmset disablesleep 0

echo "Verifying power setting:"
/usr/bin/pmset -g | grep -i "SleepDisabled" || true

echo "Unregistering SMAppService daemon if registered..."
sudo launchctl bootout system/com.sramzz.mac-no-sleep.helper 2>/dev/null || true

echo "Helper reset and uninstall complete."
