#!/usr/bin/env bash
# mise description="Bundles the Tuist macOS app for distribution"

set -euo pipefail

TMP_DIR=$(mktemp -d)
KEYCHAIN_PATH=$TMP_DIR/keychain.keychain
KEYCHAIN_PASSWORD=$(uuidgen)
BUILD_DIRECTORY=$MISE_PROJECT_ROOT/app/build
APP_DIRECTORY=$MISE_PROJECT_ROOT/app/app-binary
DERIVED_DATA_PATH=$BUILD_DIRECTORY/app/derived
BUILD_DIRECTORY_BINARY=$DERIVED_DATA_PATH/Build/Products/Release/Tuist.app
BUILD_ARTIFACTS_DIRECTORY=$BUILD_DIRECTORY/artifacts
BUILD_ZIP_PATH=$BUILD_ARTIFACTS_DIRECTORY/app.zip
SHASUMS256_FILE=$BUILD_ARTIFACTS_DIRECTORY/SHASUMS256.txt
SHASUMS512_FILE=$BUILD_ARTIFACTS_DIRECTORY/SHASUMS512.txt
TEAM_ID='U6LC622NKF'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${YELLOW}$1${NC}"
}

# Remove temporary directory on exit
trap "rm -rf $TMP_DIR" EXIT

# Codesign
print_status "Code signing the Tuist App..."
if [ "${CI:-}" = "true" ]; then
    print_status "Creating a new temporary keychain..."
    security create-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_PATH
    security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
    security default-keychain -s $KEYCHAIN_PATH
    security unlock-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_PATH
fi

echo $BASE_64_DEVELOPER_ID_APPLICATION_CERTIFICATE | base64 --decode > $TMP_DIR/certificate.p12 && security import $TMP_DIR/certificate.p12 -P $CERTIFICATE_PASSWORD -A
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
echo $BASE_64_MACOS_DISTRIBUTION_PROVISIONING_PROFILE | base64 --decode > "$HOME/Library/MobileDevice/Provisioning Profiles/tuist.mobileprovision"

# Build
print_status "Building the Tuist App..."
tuist generate --no-binary-cache --no-open
xcodebuild clean build -workspace $MISE_PROJECT_ROOT/Tuist.xcworkspace -scheme TuistApp -configuration Release -destination generic/platform=macOS -derivedDataPath $DERIVED_DATA_PATH CODE_SIGN_IDENTITY="Developer ID Application: Tuist GmbH (U6LC622NKF)" CODE_SIGN_STYLE="Manual" CODE_SIGN_INJECT_BASE_ENTITLEMENTS="NO"
codesign --force --timestamp --options runtime --sign "Developer ID Application: Tuist GmbH (U6LC622NKF)" "$BUILD_DIRECTORY_BINARY/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --timestamp --options runtime --sign "Developer ID Application: Tuist GmbH (U6LC622NKF)" "$BUILD_DIRECTORY_BINARY/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app/Contents/MacOS/Updater"
codesign --force --timestamp --options runtime --sign "Developer ID Application: Tuist GmbH (U6LC622NKF)" "$BUILD_DIRECTORY_BINARY/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
codesign --force --timestamp --options runtime --sign "Developer ID Application: Tuist GmbH (U6LC622NKF)" "$BUILD_DIRECTORY_BINARY/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"

# Notarize
print_status "Submitting the Tuist App for notarization..."
mkdir -p $BUILD_ARTIFACTS_DIRECTORY

BUILD_DMG_PATH=$BUILD_ARTIFACTS_DIRECTORY/Tuist.dmg
create-dmg --background $MISE_PROJECT_ROOT/assets/dmg-background.png --hide-extension "Tuist.app" --icon "Tuist.app" 139 161 --icon-size 95 --window-size 605 363 --app-drop-link 467 161 --volname "Tuist App" "$BUILD_DMG_PATH" "$BUILD_DIRECTORY_BINARY"
codesign --force --timestamp --options runtime --sign "Developer ID Application: Tuist GmbH (U6LC622NKF)" --identifier "dev.tuist.app.tuist-app-dmg" "$BUILD_DMG_PATH"

xcrun notarytool submit "${BUILD_DMG_PATH}" \
    --wait \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --output-format json | jq -r '.id')

# Generating shasums
print_status "Generating shasums..."
for file in "$BUILD_ARTIFACTS_DIRECTORY"/*; do
    if [ -f "$file" ] && [[ $(basename "$file") != SHASUMS* ]]; then
        shasum -a 256 "$file" | awk '{print $1 "  " FILENAME}' FILENAME=$(basename "$file") >> "$SHASUMS256_FILE"
        shasum -a 512 "$file" | awk '{print $1 "  " FILENAME}' FILENAME=$(basename "$file") >> "$SHASUMS512_FILE"
    fi
done
