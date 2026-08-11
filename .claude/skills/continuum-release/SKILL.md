---
name: continuum-release
description: Use when building, running, screenshotting, or releasing the Continuum iOS app — launching it in the simulator, driving its UI to verify a visual change, or shipping a version to TestFlight/App Store. Contains the verified account facts, the toolchain floor (iOS 26 SDK), the signing setup, and the archive→upload→submit runbook.
---

# Continuum release & verification runbook

SwiftUI + SwiftData habit tracker with a widget extension. Bundle
`orion-labs.continuum`, widget `continuumWidget`, app group
`group.com.orionlabs.continuum`, CloudKit container
`iCloud.com.orionlabs.continuum`.

Release *gates* (what to test before shipping) live in `RELEASE_CHECKLIST.md`.
This file is the *mechanics*: commands, toolchain floors, signing, and how to
verify a change visually.

## Verified account facts

| Thing | Value |
|---|---|
| Team ID | `NVN2NY8GZC` |
| ASC API key ID | `6M245PSNS9` |
| ASC key path | `~/.appstoreconnect/private_keys/AuthKey_6M245PSNS9.p8` |
| ASC issuer UUID | **NOT RECORDED — see "Issuer ID" below. Fill this in.** |
| Apple ID | `rf@stoaked.co` |

## Toolchain floor — check FIRST, it invalidates everything else

Since **April 28, 2026** App Store Connect rejects any iOS upload not built
with the **iOS 26 SDK**, i.e. **Xcode 26+**. Verify before any release work:

```bash
xcodebuild -version                      # need 26.x
xcodebuild -showsdks | grep -i "iOS "    # need iphoneos26.x
sw_vers -productVersion                  # Xcode 26.0–26.3 need macOS >= 15.6
```

- Xcode **26.0–26.3** run on macOS Sequoia **15.6+**.
- Xcode **26.4+** requires macOS Tahoe **26.2+**.
- Pick the newest Xcode matching the installed macOS; don't upgrade macOS just
  to get a newer Xcode unless something needs it.

Install a specific version without the Mac App Store:

```bash
brew install xcodes
xcodes list | grep -E "^26\.[0-9.]+ \(" | grep -viE "beta|candidate"
xcodes install 26.3        # prompts for Apple ID + 2FA — needs a human
xcodes select 26.3
```

`xcodes install` needs interactive Apple ID auth. An agent cannot complete the
2FA prompt alone; hand this step to the user.

### You probably don't need local Xcode 26 at all — build on CI

**Preferred path.** `.github/workflows/release.yml` builds on GitHub's
`macos-26` runner, which ships **Xcode 26.6** (and 26.0–26.3). That sidesteps
the local toolchain, the macOS upgrade, and the ~10 GB download completely:

```bash
gh workflow run release.yml                              # build what's on main
gh workflow run release.yml -f build_number=5            # ASC rejects duplicate build numbers
gh run watch $(gh run list -w release.yml -L1 --json databaseId -q '.[0].databaseId')
```

Needs three repo secrets. `ASC_KEY_ID` and `ASC_KEY_P8_BASE64` are already set;
**`ASC_ISSUER_ID` is the one value that requires a human** (see "Issuer ID"):

```bash
gh secret set ASC_ISSUER_ID --body "<ISSUER-UUID>"
```

Signing needs no p12: `-allowProvisioningUpdates` plus the ASC API key mints the
Apple Distribution cert on the clean runner.

### Local Xcode 26 — only if you truly need to build on this Mac

Every route ends at an Apple authentication boundary, so prefer CI above:

| Route | Blocker |
|---|---|
| `xcodes install 26.x` | Apple ID + 2FA prompt |
| Mac App Store / `mas` | signed-in App Store account |
| developer.apple.com .xip | authenticated web session |
| macOS update (needed to *run* Xcode 26) | `sudo` password, then a restart |

Browser automation does not rescue the local path either. Both stacks were
unavailable on 2026-08-11:
`claude-in-chrome` reported "extension is not connected", and
`chrome-devtools` MCP refused with "browser is already running for
`~/.cache/chrome-devtools-mcp/chrome-profile`" (its Chrome uses
`--remote-debugging-pipe`, so there's no TCP port to attach to, and
`--isolated` isn't settable from the tool call). Even when it works, that MCP
uses its own scratch profile with **no Apple session**, so a human sign-in is
still required.

**Conclusion: use CI.** The only thing a human must supply is the issuer UUID,
because it lives solely behind an authenticated App Store Connect session.
Record it in the table above so it's a one-time cost. Never attempt to ship with
an older SDK — App Store Connect rejects it outright, so there is no
partial-credit path, and never fake `DTSDKName` to look newer.

### Disk space

Xcode 26 needs roughly **60–80 GB free** (≈10 GB .xip + expansion + install).
Safe, fully regenerable things to clear, largest first:

```bash
rm -rf "$HOME/Library/Developer/Xcode/iOS DeviceSupport"   # tens of GB; rebuilt per device
rm -rf "$HOME/Library/Developer/Xcode/DerivedData"         # rebuilt on next build
xcrun simctl delete unavailable                            # keeps available sims + their data
brew cleanup --prune=all
```

Never clear `~/Documents`, `~/dev`, `~/models`, or
`~/Library/Developer/Xcode/Archives` (real release artifacts).

If a GateGuard hook blocks `rm -rf`, don't disable the hook — hand the user the
command prefixed with `!` so they run it themselves.

## Signing

The App Store needs an **Apple Distribution** identity. Check:

```bash
security find-identity -v -p codesigning | grep -i distribution
defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists  # empty = no Xcode account
```

An `Apple Development` cert alone is **not** enough. Archiving still succeeds
(development-signed, and `-allowProvisioningUpdates` quietly falls back to it),
but export/upload fails — so check the archive's `SigningIdentity`, don't trust
`ARCHIVE SUCCEEDED`. Fix by signing into Xcode (Settings → Accounts) as Team
Agent/Admin, or let `-allowProvisioningUpdates` mint one once the ASC API key
is supplied.

## Issuer ID

Only obtainable from the web UI: **App Store Connect → Users and Access →
Integrations → App Store Connect API**, shown as "Issuer ID" at the top. It
cannot be derived from the `.p8`. Once you have it, **write it into the table
above** so future releases are unattended.

## Release runbook

**Use the script** — it encodes every preflight below and fails fast:

```bash
./scripts/release.sh <ASC_ISSUER_UUID>
```

It verifies the ASC key, the iOS 26+ SDK, the distribution identity, and
version consistency across all 8 configs; runs the tests; archives; asserts the
archive is *actually* distribution-signed; then uploads. It stops before
submission on purpose.

The manual equivalent, step by step:

```bash
# 1. Preflight
xcodebuild test -scheme continuum -testPlan continuum \
  -destination 'platform=iOS Simulator,name=iPhone 16 Plus'   # expect 32/32

# 2. Bump version — 8 occurrences each, app + widget + test targets.
#    Widget Info.plist already tracks $(MARKETING_VERSION)/$(CURRENT_PROJECT_VERSION).
sed -i '' 's/MARKETING_VERSION = 3\.4;/MARKETING_VERSION = 3.5;/g; \
           s/CURRENT_PROJECT_VERSION = 4;/CURRENT_PROJECT_VERSION = 5;/g' \
  continuum.xcodeproj/project.pbxproj
grep -o "MARKETING_VERSION = [0-9.]*;" continuum.xcodeproj/project.pbxproj | sort | uniq -c

# 3. Archive
xcodebuild archive -scheme continuum -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Continuum.xcarchive -allowProvisioningUpdates

# verify what you actually built
/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' \
  -c 'Print :ApplicationProperties:CFBundleVersion' \
  -c 'Print :ApplicationProperties:SigningIdentity' build/Continuum.xcarchive/Info.plist
plutil -extract DTSDKName raw build/Continuum.xcarchive/Products/Applications/continuum.app/Info.plist

# 4. Upload
cat > build/exportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>NVN2NY8GZC</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>upload</string>
</dict></plist>
PLIST

xcodebuild -exportArchive \
  -archivePath build/Continuum.xcarchive \
  -exportOptionsPlist build/exportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_6M245PSNS9.p8 \
  -authenticationKeyID 6M245PSNS9 \
  -authenticationKeyIssuerID <ISSUER-UUID>
```

Then **stop and get human sign-off** before submitting for review. The gates in
`RELEASE_CHECKLIST.md` are deliberate: upgrade-path test on real data,
TestFlight soak, phased release ON (this app touches the data layer + CloudKit).

## Running it in the simulator

```bash
SIM=$(xcrun simctl list devices available | grep -m1 "iPhone 16 Plus" | grep -oE "[0-9A-F-]{36}")
open -a Simulator
xcodebuild -scheme continuum -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath /tmp/dd build
xcrun simctl install $SIM /tmp/dd/Build/Products/Debug-iphonesimulator/continuum.app
xcrun simctl launch $SIM orion-labs.continuum
xcrun simctl io $SIM screenshot shot.png
```

**Always look at the screenshot.** A green build proves nothing about layout,
z-order, or fonts — three real bugs in the 3.4 celebration work were invisible
to the compiler and obvious on screen.

### Driving the UI (taps)

`simctl` has no tap command. Use `cliclick` against the Simulator window:

```bash
osascript -e 'tell application "System Events" to tell process "Simulator" \
  to get {position, size} of window 1'      # e.g. 1174, 50, 484, 1030
```

Device origin = window origin + **27pt bezel**, plus **44pt titlebar** on y.
For a 430x932pt device in a 484x1030 window at (1174,50):
`screen_x = 1201 + pt_x`, `screen_y = 121 + pt_y`, and `pt = screenshot_px / 3`.

```bash
osascript -e 'tell application "Simulator" to activate'   # REQUIRED before each batch
sleep 1
cliclick c:1233,196                                   # tap
cliclick dd:1311,559; sleep 2; cliclick du:1311,559   # hold-to-complete gesture
```

Gotchas: clicks are silently dropped unless the window was just activated, and
`kp:esc` does **not** dismiss a SwiftUI context menu — tap empty space instead.

### Screenshotting transient overlays

Screenshots take ~1s, so you cannot catch a 2.4s auto-dismissing celebration by
bursting. Add a temporary env-var-gated harness to `continuumApp.swift`:

```swift
if let which = ProcessInfo.processInfo.environment["CELEB"] {
    CelebrationReviewHarness(which: which)   // re-presents itself on dismiss
} else { ContentView() }
```

```bash
SIMCTL_CHILD_CELEB=graduation xcrun simctl launch $SIM orion-labs.continuum
```

Back up the file first and **revert it before committing**; verify with
`git diff --stat continuum/continuumApp.swift` (must be empty).

## Design gotchas learned the hard way

- **SF Mono has no `.black` weight.** `.system(weight: .black, design: .monospaced)`
  silently falls back to SF Pro, so the text looks foreign beside the rest of
  the app. Cap at `.heavy`. The app sets `.fontDesign(.monospaced)` globally in
  `continuumApp.swift`; any explicit `design:` overrides it.
- **A stroke inside a view that is later `.clipShape`d loses its outer half**
  and any glow entirely. Apply borders as an `.overlay` outside the clip and use
  `.strokeBorder` (draws inward).
- **`.blendMode()` pushes a view into its own compositing group** that can draw
  *over* later ZStack siblings instead of behind them. Drop the blend mode or
  set explicit `.zIndex`.
- Masking a `Text` with itself to constrain an effect also clips its shadow.
  Mask the effect overlay, not the whole view.
- Respect `@Environment(\.accessibilityReduceMotion)` for the ignition wave and
  border trace, and `ProcessInfo.processInfo.isLowPowerModeEnabled` for card
  animations.
- A radial wave animation must travel **past** the screen edge. If the front
  stops at its max radius, cells just inside it freeze mid-flash forever; make
  brightness the tunable, not reach.

## Test suite

32 tests, and they **must stay serialized** — the suite was flaky from
parallel-execution races. Canonical day storage is **12:00:30 UTC**; the `:30`
is load-bearing (a UTC+12 collision), so never "simplify" it to noon.
