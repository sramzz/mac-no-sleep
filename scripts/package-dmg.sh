#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Prevent Sleep - Production DMG Packager & Notarization Pipeline
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
STAGING_DIR="$BUILD_DIR/dmg_staging"
OUTPUT_DMG="$BUILD_DIR/PreventSleep.dmg"

SIGNING_IDENTITY=""
NOTARIZE_PROFILE=""
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --identity <name>         Code signing identity (e.g., "Developer ID Application: Your Name (TEAMID)")
  --notarize <profile>      Notarize DMG using saved notarytool keychain profile
  --help                    Show this help message

If no identity is specified, the script searches for "Developer ID Application",
then "Apple Development", and falls back to local ad-hoc signing ("-").
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --notarize)
            NOTARIZE_PROFILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo "============================================================"
echo "☕️  Packaging Prevent Sleep for Direct Distribution"
echo "============================================================"

# 1. Detect Signing Identity if not explicitly provided
if [ -z "$SIGNING_IDENTITY" ]; then
    echo "🔍 Detecting code signing identity..."
    # First try Developer ID Application (required for public distribution)
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}' || true)

    # Fallback to Apple Development (for local device testing)
    if [ -z "$SIGNING_IDENTITY" ]; then
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)
    fi

    # Fallback to ad-hoc
    if [ -z "$SIGNING_IDENTITY" ]; then
        SIGNING_IDENTITY="-"
        echo "⚠️  No Developer ID or Apple Development certificate found in Keychain."
        echo "ℹ️  Using ad-hoc signing ('-'). Suitable for local testing only."
    else
        echo "✅ Using identity: $SIGNING_IDENTITY"
    fi
else
    echo "✅ Using specified identity: $SIGNING_IDENTITY"
fi

if [ -n "$NOTARIZE_PROFILE" ] && [[ "$SIGNING_IDENTITY" != *"Developer ID Application"* ]]; then
    echo "⚠️  Warning: Notarization requires a 'Developer ID Application' certificate."
    echo "   Current identity: $SIGNING_IDENTITY"
fi

# 2. Build Release Target
echo ""
echo "📦 Step 1: Generating project & compiling Release build..."
cd "$PROJECT_DIR"
xcodegen generate

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
  -project PreventSleep.xcodeproj \
  -scheme PreventSleep \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build > /dev/null

BUILT_APP="$DERIVED_DATA/Build/Products/Release/PreventSleep.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Error: Could not find compiled PreventSleep.app at $BUILT_APP"
    exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$STAGING_DIR"

APP_PATH="$STAGING_DIR/PreventSleep.app"
cp -R "$BUILT_APP" "$APP_PATH"
echo "✅ Copied built app to staging directory."

# 3. Sign All Components with Hardened Runtime
echo ""
echo "🔐 Step 2: Signing application binaries with Hardened Runtime..."

SIGN_OPTS=("-o" "runtime" "--force")
if [ "$SIGNING_IDENTITY" != "-" ]; then
    SIGN_OPTS+=("--timestamp")
fi

# Sign helper tool
if [ -f "$APP_PATH/Contents/MacOS/com.sramzz.mac-no-sleep.helper" ]; then
    codesign -s "$SIGNING_IDENTITY" "${SIGN_OPTS[@]}" \
      --entitlements "$PROJECT_DIR/Sources/PreventSleepHelper/Resources/PreventSleepHelper.entitlements" \
      -i "com.sramzz.mac-no-sleep.helper" \
      "$APP_PATH/Contents/MacOS/com.sramzz.mac-no-sleep.helper"
fi

# Sign embedded dylibs / frameworks
find "$APP_PATH/Contents/MacOS" -name "*.dylib" -exec codesign -s "$SIGNING_IDENTITY" "${SIGN_OPTS[@]}" {} + 2>/dev/null || true
if [ -d "$APP_PATH/Contents/Frameworks" ]; then
    find "$APP_PATH/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm +111 \) -exec codesign -s "$SIGNING_IDENTITY" "${SIGN_OPTS[@]}" {} + 2>/dev/null || true
fi

# Sign main app bundle
codesign -s "$SIGNING_IDENTITY" "${SIGN_OPTS[@]}" \
  --entitlements "$PROJECT_DIR/Sources/PreventSleepApp/Resources/PreventSleep.entitlements" \
  "$APP_PATH"

echo "🔍 Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "✅ Code signature verified."

# 4. Create Applications Symlink in Staging
echo ""
echo "💿 Step 3: Generating disk image (.dmg)..."
ln -s /Applications "$STAGING_DIR/Applications"

# Remove any old DMG
rm -f "$OUTPUT_DMG"

# Create UDZO compressed DMG
hdiutil create \
  -volname "Prevent Sleep" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG" > /dev/null

echo "✅ DMG created at: $OUTPUT_DMG"

# 5. Sign the DMG itself
if [ "$SIGNING_IDENTITY" != "-" ]; then
    echo "🔐 Signing disk image..."
    codesign -s "$SIGNING_IDENTITY" --timestamp "$OUTPUT_DMG"
    echo "✅ DMG signed."
fi

# 6. Notarization (if profile provided)
if [ -n "$NOTARIZE_PROFILE" ]; then
    echo ""
    echo "🚀 Step 4: Submitting to Apple Notary Service..."
    echo "Submitting $OUTPUT_DMG using keychain profile '$NOTARIZE_PROFILE'..."
    xcrun notarytool submit "$OUTPUT_DMG" --keychain-profile "$NOTARIZE_PROFILE" --wait

    echo "📎 Stapling notarization ticket to DMG..."
    xcrun stapler staple "$OUTPUT_DMG"
    echo "✅ Notarization & stapling complete!"
else
    echo ""
    echo "ℹ️  Step 4: Notarization skipped."
    echo "   To notarize for public distribution, provide --notarize <keychain-profile>."
    echo "   See docs/DISTRIBUTION.md for instructions on setting up Apple Notarytool."
fi

echo ""
echo "============================================================"
echo "🎉 SUCCESS: Ready-to-distribute DMG generated!"
echo "📍 Location: $OUTPUT_DMG"
echo "============================================================"
