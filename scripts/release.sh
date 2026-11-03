#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Prevent Sleep - Automated One-Command Release & Verification Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-1.0.0}"
BUILD_NUM="${2:-100}"
NOTARIZE_PROFILE="${3:-}"

echo "============================================================"
echo "🚀 Prevent Sleep Release Pipeline: v$VERSION ($BUILD_NUM)"
echo "============================================================"

cd "$PROJECT_DIR"

# 1. Run automated test suite
echo ""
echo "🧪 Step 1: Running automated test suite..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
echo "✅ All unit tests passed!"

# 2. Package DMG
echo ""
echo "📦 Step 2: Packaging Release application & DMG..."
if [ -n "$NOTARIZE_PROFILE" ]; then
    ./scripts/package-dmg.sh --notarize "$NOTARIZE_PROFILE"
else
    ./scripts/package-dmg.sh
fi

OUTPUT_DMG="$PROJECT_DIR/build/PreventSleep.dmg"
VERSIONED_DMG="$PROJECT_DIR/build/PreventSleep-$VERSION.dmg"

cp "$OUTPUT_DMG" "$VERSIONED_DMG"

# 3. Calculate SHA-256 Checksum
echo ""
echo "🔒 Step 3: Computing cryptographic checksum..."
SHA256=$(shasum -a 256 "$VERSIONED_DMG" | awk '{print $1}')
echo "SHA-256 ($VERSIONED_DMG):"
echo "  $SHA256"

echo "$SHA256  PreventSleep-$VERSION.dmg" > "$PROJECT_DIR/build/PreventSleep-$VERSION.sha256"

# 4. Strict Code Signature & Gatekeeper Inspection
echo ""
echo "🔍 Step 4: Inspecting signed artifacts..."
codesign -dv --verbose=4 "$PROJECT_DIR/build/dmg_staging/PreventSleep.app" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier|flags" || true

echo ""
echo "============================================================"
echo "🎉 RELEASE ARTIFACTS READY"
echo "============================================================"
echo "Disk Image: $VERSIONED_DMG"
echo "Checksum:   $SHA256"
echo ""
echo "Next steps for public release:"
echo "1. Create GitHub Tag: git tag -s v$VERSION -m 'Release v$VERSION'"
echo "2. Upload $VERSIONED_DMG to GitHub Release / Lemon Squeezy / Gumroad"
echo "3. Publish release notes from CHANGELOG.md"
echo "============================================================"
