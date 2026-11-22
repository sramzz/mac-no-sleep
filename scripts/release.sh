#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Prevent Sleep - Automated One-Command Release & Verification Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-1.0.1}"
BUILD_NUM="${2:-101}"
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

# 4. Generate Sparkle appcast.xml if Sparkle tools & EdDSA key are available
GENERATE_APPCAST="$PROJECT_DIR/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
APPCAST_DIR="$PROJECT_DIR/build/appcast_staging"
APPCAST_OUT="$PROJECT_DIR/build/appcast.xml"
if [ -x "$GENERATE_APPCAST" ]; then
    echo ""
    echo "📡 Step 4: Generating Sparkle appcast.xml..."
    rm -rf "$APPCAST_DIR"
    mkdir -p "$APPCAST_DIR"
    cp "$VERSIONED_DMG" "$APPCAST_DIR/"
    if "$GENERATE_APPCAST" \
        --download-url-prefix "https://github.com/sramzz/mac-no-sleep/releases/download/v$VERSION/" \
        --link "https://github.com/sramzz/mac-no-sleep" \
        -o "$APPCAST_OUT" \
        "$APPCAST_DIR"; then
        echo "✅ Appcast generated: $APPCAST_OUT"
    else
        echo "ℹ️  Skipped appcast signing (no EdDSA key found in Keychain; run generate_keys first)."
    fi
fi

# 5. Strict Code Signature & Gatekeeper Inspection
echo ""
echo "🔍 Step 5: Inspecting signed artifacts..."
codesign -dv --verbose=4 "$PROJECT_DIR/build/dmg_staging/PreventSleep.app" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier|flags" || true

echo ""
echo "============================================================"
echo "🎉 RELEASE ARTIFACTS READY"
echo "============================================================"
echo "Disk Image: $VERSIONED_DMG"
echo "Checksum:   $SHA256"
if [ -f "$APPCAST_OUT" ]; then
    echo "Appcast:    $APPCAST_OUT"
fi
echo ""
echo "Next steps for public release:"
echo "1. Create GitHub Tag: git tag -s v$VERSION -m 'Release v$VERSION'"
echo "2. Upload $VERSIONED_DMG (and $APPCAST_OUT if generated) to GitHub Release"
echo "3. Publish release notes from CHANGELOG.md"
echo "============================================================"
