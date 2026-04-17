#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/NetworkTools.xcodeproj"
SCHEME="NetworkTools"

ARCHIVE_PATH="${ARCHIVE_PATH:-/tmp/NetworkToolsRelease.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-/tmp/NetworkToolsReleaseExport}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-/tmp/NetworkToolsExportOptions.plist}"
ZIP_PATH="${ZIP_PATH:-$EXPORT_PATH/NetworkTools.zip}"
APP_PATH="$EXPORT_PATH/NetworkTools.app"

APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
DEVELOPER_ID_IDENTITY="${DEVELOPER_ID_IDENTITY:-Developer ID Application}"
INSTALL_TO_APPLICATIONS="${INSTALL_TO_APPLICATIONS:-0}"

function require_env() {
  local name="$1"
  if [[ -z "${(P)name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_env APPLE_TEAM_ID

NOTARY_ARGS=()
if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
else
  require_env NOTARY_APPLE_ID
  require_env NOTARY_TEAM_ID
  require_env NOTARY_PASSWORD
  NOTARY_ARGS=(
    --apple-id "$NOTARY_APPLE_ID"
    --team-id "$NOTARY_TEAM_ID"
    --password "$NOTARY_PASSWORD"
  )
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$ZIP_PATH"
mkdir -p "$EXPORT_PATH"

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
</dict>
</plist>
EOF

echo "Archiving signed Release build..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_IDENTITY"

echo "Exporting Developer ID app..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected exported app at $APP_PATH" >&2
  exit 1
fi

echo "Creating notarization zip..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting to notarization..."
xcrun notarytool submit "$ZIP_PATH" "${NOTARY_ARGS[@]}" --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

echo "Verifying signature and Gatekeeper acceptance..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv "$APP_PATH"

if [[ "$INSTALL_TO_APPLICATIONS" == "1" ]]; then
  echo "Installing to /Applications..."
  ditto "$APP_PATH" /Applications/NetworkTools.app
fi

echo "Release app ready at: $APP_PATH"
