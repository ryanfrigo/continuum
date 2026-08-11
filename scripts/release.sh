#!/bin/bash
#
# Continuum App Store release: preflight -> test -> archive -> upload.
#
#   ./scripts/release.sh <ASC_ISSUER_UUID>
#
# Stops at upload. Submission for review is deliberately manual:
# RELEASE_CHECKLIST.md gates release on a real-data upgrade test + TestFlight
# soak, and this app touches the data layer + CloudKit.
#
# Mechanics and gotchas: .claude/skills/continuum-release/SKILL.md

set -euo pipefail

ISSUER="${1:-${ASC_ISSUER_ID:-}}"

TEAM_ID="NVN2NY8GZC"
KEY_ID="6M245PSNS9"
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/Continuum.xcarchive"

die() { printf '\n\033[31mFAIL\033[0m  %s\n' "$1" >&2; exit 1; }
ok()  { printf '\033[32mok\033[0m    %s\n' "$1"; }

cd "$(dirname "$0")/.."

# ---------------------------------------------------------------- preflight
# Every one of these has actually bitten this project. Check before spending
# ten minutes on an archive that cannot be uploaded.

[ -n "$ISSUER" ] || die "Missing issuer UUID.
  Usage: ./scripts/release.sh <ASC_ISSUER_UUID>
  Get it from App Store Connect -> Users and Access -> Integrations ->
  App Store Connect API ('Issuer ID', top of the page).
  Then record it in .claude/skills/continuum-release/SKILL.md."

[ -f "$KEY_PATH" ] || die "ASC private key not found at $KEY_PATH"
ok "ASC key present ($KEY_ID)"

# App Store Connect has rejected non-iOS-26-SDK uploads since 2026-04-28.
if ! xcodebuild -showsdks 2>/dev/null | grep -qE "iphoneos(2[6-9]|[3-9][0-9])"; then
  die "No iOS 26+ SDK. Have: $(xcodebuild -version | head -1).
  App Store Connect rejects anything older (since 2026-04-28).
    brew install xcodes && xcodes install 26.3 && xcodes select 26.3
  Xcode 26.0-26.3 need macOS >= 15.6; 26.4+ needs macOS Tahoe 26.2+.
  Current macOS: $(sw_vers -productVersion)"
fi
ok "iOS 26+ SDK available ($(xcodebuild -version | head -1))"

# An Apple Development cert still lets `archive` succeed, then export fails.
if security find-identity -v -p codesigning | grep -qi "Apple Distribution"; then
  ok "Apple Distribution identity present"
else
  printf '\033[33mwarn\033[0m  No "Apple Distribution" identity found locally.\n'
  printf '      Relying on -allowProvisioningUpdates + the ASC key to mint one.\n'
  printf '      If that fails, sign into Xcode (Settings -> Accounts) as Team Agent/Admin.\n'
fi

VERSION=$(grep -m1 -o 'MARKETING_VERSION = [0-9.]*;' continuum.xcodeproj/project.pbxproj | grep -o '[0-9.]*')
BUILD_NUM=$(grep -m1 -o 'CURRENT_PROJECT_VERSION = [0-9]*;' continuum.xcodeproj/project.pbxproj | grep -o '[0-9]*')
ok "Releasing $VERSION (build $BUILD_NUM)"

# Version must match across app + widget + test targets, or App Store Connect
# rejects the bundle for a widget/app version mismatch (happened in 3.2).
[ "$(grep -c "MARKETING_VERSION = ${VERSION};" continuum.xcodeproj/project.pbxproj)" -eq 8 ] \
  || die "MARKETING_VERSION is not $VERSION in all 8 build configs"
ok "Version consistent across all 8 configs"

# ------------------------------------------------------------------- tests
# The suite must stay serialized -- it was flaky from parallel-execution races.
SIM=$(xcrun simctl list devices available \
      | grep -m1 -E "iPhone 1[6-9]" \
      | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}") \
  || die "No iPhone simulator available"

xcodebuild test -scheme continuum -testPlan continuum \
  -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath "$BUILD_DIR/dd" 2>&1 | grep -q "TEST SUCCEEDED" \
  || die "Tests failed -- not shipping"
ok "Tests passed"

# ----------------------------------------------------------------- archive
rm -rf "$ARCHIVE"
mkdir -p "$BUILD_DIR"
xcodebuild archive -scheme continuum -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" 2>&1 | grep -q "ARCHIVE SUCCEEDED" \
  || die "Archive failed"

# ARCHIVE SUCCEEDED does not mean distribution-signed. Verify before uploading.
SIGNED_BY=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:SigningIdentity' "$ARCHIVE/Info.plist")
ARCH_SDK=$(plutil -extract DTSDKName raw "$ARCHIVE/Products/Applications/continuum.app/Info.plist")
ok "Archived $VERSION ($BUILD_NUM), sdk=$ARCH_SDK, signed by: $SIGNED_BY"

# Commonly Development-signed even for App Store builds: -exportArchive with
# signingStyle=automatic re-signs with the Apple Distribution cert via the ASC
# key. Informational -- export is the real arbiter.
case "$SIGNED_BY" in
  *Distribution*) ok "Already distribution-signed" ;;
  *) printf '\033[33mwarn\033[0m  Archive is '"'"'%s'"'"'; export will re-sign for distribution\n' "$SIGNED_BY" ;;
esac

# ------------------------------------------------------------------ upload
cat > "$BUILD_DIR/exportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>upload</string>
</dict></plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_DIR/exportOptions.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" \
  || die "Upload failed"

ok "Uploaded $VERSION ($BUILD_NUM) to App Store Connect"

cat <<'EOF'

Next: TestFlight processing takes ~5-15 min. Then, per RELEASE_CHECKLIST.md:
  - upgrade-path test on real data (riskiest moment for shipped users)
  - TestFlight soak for a few days
  - phased release ON

Submission for review is intentionally not automated.
EOF
