# Continuum — Release Checklist

## iCloud sync never worked in production until 2026-09-21

The CloudKit **schema was never deployed to Production**. The console showed
`Record type 'CD_Habit' cannot be found` in Production while Development had
it with 18 fields. So from 3.3 (July 2026, where iCloud sync was the headline
"What's New" item) through 3.4, every shipped build's CloudKit export failed
and silently fell back to the local-only store — exactly the failure mode step
3 of the 3.3 checklist warned about, unticked. Deployed 2026-09-21.

Lesson for every release from here: **verify the record type in the Production
environment**, not just that the deploy step is on a list. The local-only
fallback means a broken sync produces no crash, no bad review, no signal.

## 3.5 (build 5) — notification fixes + per-day sync

**3.4 (build 4) shipped to the App Store on 2026-08-11** via
`.github/workflows/release.yml` on the `macos-26` runner. All three `ASC_*`
secrets are set, so the CI upload runs unattended. As of 2026-09-17 the live
listing is 3.4, free, 4 ratings at 5.0, first released 2025-10-24.

Changed 2026-09-14. 49/49 unit tests pass (12 notification planner, 5 sync
ledger). An upgrade install over a seeded 3.3-schema store in the simulator
migrated cleanly (new entity added, habit and its 5 completed days intact).
An independent review then caught a resurrection bug with 3.3 devices; fixed
before commit (see item 3).

What's in it:

- **Notifications rebuilt.** Reminders said "Day one is waiting" to people on
  40-day streaks (the streak read 0 until today was marked). Checking off from
  the widget didn't cancel that day's reminder or the 8pm alert. IDs are now
  keyed by date (`habit-reminder-<uuid>-20260914`), the horizon is 3 days
  instead of 7, and the 8pm alert only fires for habits with reminders on —
  never when a streak freeze would save it, never on top of a reminder set at
  8pm or later. Capped at iOS's 64-pending limit, soonest first.
- **Per-day sync ledger.** Each (habit, day) edit is its own `CompletionMark`
  CloudKit record, so Monday on the phone and Tuesday on the iPad both
  survive. The `completedDates` array stays (3.3 devices still use it) and is
  rebuilt from the ledger on launch, activation, and remote change. Days no
  3.4 device has touched still follow the array, exactly like 3.3.
- **Celebrations moved into the tile.** Streak milestones, personal records
  and health milestones now celebrate inside the habit's own card for 2.4s;
  tapping a shareable one opens the share card. Graduation, perfect day,
  perfect week and streak-saved stay full-screen.
- **Graduation fired every day.** `previousStreaks` was seeded from
  `currentStreak()`, which reads 0 until today is marked, so any 66+ day habit
  looked like it had just crossed the line on every completion. Seeded from
  yesterday now, and graduation is gated on `checkAndMarkGraduation()` so it
  can only happen once per habit.
- **Reminders are finally offered.** The app never mentioned reminders — you
  had to find the per-habit toggle in Settings, so almost nobody had them on
  and none of the notification work reached anyone. It now asks once, after
  the first completion, defaulting to 9:00 AM. The iOS permission dialog only
  appears if they tap REMIND ME, so "Not now" doesn't spend the single system
  prompt. Verify in the on-device pass: fresh install → create habit →
  complete → prompt appears → REMIND ME turns reminders on for every habit.
- **Widget fixes.** The widget showed `currentStreak`, which reads 0 until
  today is marked, so a habit's streak line disappeared each morning and left
  the two medium-widget cards misaligned. Both app and widget now use
  `HabitData.displayStreak`, the streak row always renders, the history grid
  fills the card width (it was squeezed by a fixed aspect ratio), and the
  health ring sits beside its percentage instead of being clipped by the
  widget's corner.
- **Shared cards carry the App Store link** (`AppStoreLink.shareItems`), so a
  screenshot someone posts is something a reader can act on.
- Reminder toggle turns on after the permission prompt; it used to need a
  second tap.

Before submitting, in this order:

1. ~~**Deploy the CloudKit schema to Production**~~ ✅ Done 2026-09-21.
   `CD_CompletionMark` is live in Production with all six fields, verified by
   `cktool export-schema` (not just the console UI); Development and
   Production are identical.

   How, for next time — no device or iCloud sign-in needed:
   ```bash
   xcrun cktool save-token --type management        # token from CloudKit console → Tokens & Keys
   xcrun cktool export-schema --team-id NVN2NY8GZC \
     --container-id iCloud.com.orionlabs.continuum --environment development > dev.ckdb
   # add the RECORD TYPE by hand, mirroring an existing one for field types
   # (UUID → STRING, Int/Bool → INT64, Date → TIMESTAMP)
   xcrun cktool validate-schema ... --environment development --file new.ckdb
   xcrun cktool import-schema   ... --environment development --file new.ckdb
   ```
   `import-schema` **refuses Production** ("endpoint not applicable"), and
   cktool has no deploy/promote command — the Development → Production step is
   console-only, by design. Always verify after with `export-schema
   --environment production`.
2. ~~**Two-device test.**~~ Skipped by choice for 3.5. Covered instead by
   `TwoDeviceSyncTests` — two in-memory stores with records shuttled between
   them, including a habit record arriving before its marks and an
   un-completion that must not resurrect. That exercises the merge logic but
   **cannot** catch CloudKit-specific failures: a wrong field type in the
   hand-authored production schema, entitlement problems, or push delivery.
   Phased release is the net for those — watch day one at 1% and pause from
   the version page if history goes missing.
3. **Mixed-version test (if you still have a 3.3 device).** Complete a day on
   3.3, confirm it shows on 3.4; un-complete it on 3.3, confirm it clears.
   Known gap: if a 3.4 device edited that same day, the 3.4 edit sticks.
4. **Notifications on device.** Set a reminder 2 minutes out, check it off
   from the lock-screen widget, confirm nothing fires. Have a 3+ day streak
   with no freezes and reminders on; confirm one 8pm alert with the right
   number.
5. Upload: `gh workflow run release.yml -f build_number=5`, then
   `gh run watch`. Local Xcode 16.4 can't produce an accepted build; CI can,
   and did for 3.4.

Not done, and why:

- **In-app analytics** (TelemetryDeck or similar) needs an account and app ID
  from you, plus an App Privacy label change in App Store Connect. App Store
  download/retention numbers need no new SDK — see
  `.github/workflows/analytics.yml`, which reads them with the ASC secrets.
- **Tip jar** needs IAP products created in App Store Connect and the Paid
  Apps agreement signed. The ASC API could create the products, but the
  issuer ID still isn't recorded anywhere.
- `freezeUsedDates` and `streakFreezeCount` still sync last-writer-wins. Low
  stakes: at worst a freeze gets double-spent or re-granted.

---

# Continuum 3.3 — Release Checklist

Version 3.3 (build 3). Full review completed 2026-07-02: independent code
review + release-readiness audit, all blockers fixed, **32/32 unit tests
pass** (suite was flaky from parallel-execution races — now serialized and
verified stable across repeated runs).

## Fixed during review (already committed)

- **UTC+12 data corruption (blocker):** canonical dates are now 12:00:30 UTC,
  not noon — local midnight in NZ/Fiji (UTC+12) is exactly noon UTC of the
  previous day, so the old shape-detection misread and permanently shifted
  those users' entire history one day back on upgrade. Regression test added
  (`legacyAucklandMidnightsDoNotShiftBackADay`).
- **Cross-device dedupe race (blocker):** duplicate-habit keeper selection is
  now deterministic on synced fields; previously two devices could each pick
  a different keeper and delete the other's — losing the habit everywhere.
- **Widget toggles no longer droppable:** completions queued from the widget
  are re-queued (not discarded) if the habit list hasn't loaded yet on a cold
  launch; stale toggles (>48h) can no longer override later in-app edits.
- **Widget version mismatch (App Store rejection):** widget Info.plist
  hardcoded 3.2 (1); now uses $(MARKETING_VERSION)/$(CURRENT_PROJECT_VERSION).
- **Photo-library crash:** added NSPhotoLibraryAddUsageDescription ("Save
  Image" from the share-card sheet would kill the app without it).
- **CloudKit push:** added aps-environment entitlement + remote-notification
  background mode so sync is push-fresh, not launch-only. CloudKit container
  init errors are now logged instead of silently swallowed.
- **Widget DST bug:** midnight-rollover refresh no longer schedules into the
  past on 25-hour fall-back days.

## Must do before submitting (in order)

1. ~~**Xcode capability sanity check**~~ ✅ Done 2026-07-02: headless device
   build with `-allowProvisioningUpdates` + the ASC API key registered the
   App ID capabilities (iCloud/CloudKit container, app group, push) and the
   signed build carries all four entitlements. 3.3 was installed over 3.2 on
   the iPhone 16 and launched — **eyeball your streaks to confirm the
   migration** (the launch succeeded; visual check is yours).

2. **⚠️ Verify CloudKit actually syncs the data — on real devices.**
   The simulator console showed `CoreData: fault: Could not materialize ...
   "Array<Date>" of attribute named completedDates`. Install on two devices
   signed into the same iCloud account, complete a habit on one, confirm it
   appears on the other (give it a few minutes / foreground both). If history
   doesn't sync, tell Claude — fallback is encoding day keys as Data.

3. **CloudKit Console: deploy schema to Production.** After the first device
   run syncs (Development environment), go to icloud.developer.apple.com →
   your container → *Deploy Schema Changes to Production*. Skipping this is
   the #1 cause of "sync works in TestFlight, silently fails in App Store" —
   and the local-only fallback means you'd get no crash report, just no sync.
   (The fallback now logs to Console.app, so it's at least diagnosable.)

4. **Upgrade-path test (your real data).** Your phone has 3.2 with live
   streaks. Build 3.3 onto it directly over the App Store install — confirm
   streaks/history are intact (the canonical-storage migration runs on first
   launch). Don't skip; this is the riskiest moment for shipped users.

5. **On-device spot checks** (10 min):
   - Interactive widget: add small widget, tap MARK DONE from home screen,
     open app → completion + celebration appear.
   - Lock screen widgets render (circular + rectangular).
   - Share card → share sheet → "Save Image" saves without crashing.
   - Streak-at-risk notification arrives at 8pm with the new copy.
   - VoiceOver quick pass on the new overlays (labels are set).

6. **TestFlight for a few days** before release. Phased release ON —
   this build touches the data layer and adds CloudKit.
   **Blocked on Xcode 26**: App Store Connect rejects iOS 18-SDK uploads
   (verified on this account, June 2026) and this Mac has only Xcode 16.4.
   Install Xcode 26 from the Mac App Store, then the upload is one command
   (Claude has the archive + upload runbook ready with the ASC API key
   `6M245PSNS9`; exportOptions: method app-store-connect, team NVN2NY8GZC,
   automatic signing, destination upload).

### Upload attempt 2026-08-11 (3.4 build 4) — RESOLVED, shipped that day

Everything below is the state *before* CI landed; all three gates were cleared
on 2026-08-11 by building on GitHub's `macos-26` runner instead of this Mac.
Kept for the reasoning, not as current status.

Archive itself succeeds (`ARCHIVE SUCCEEDED`, verified 3.4 / build 4). Upload
cannot proceed. All three gates need a human:

1. **Still Xcode 16.4** → archive builds against `iphoneos18.5` (only SDK
   installed). The June 2026 rejection cause is unchanged. Install Xcode 26
   from the Mac App Store (Apple ID + multi-GB download).
2. **No Apple Distribution certificate on this Mac.** `security find-identity
   -v -p codesigning` returns only `Apple Development: rf@stoaked.co
   (44CX442496)`, so the archive is development-signed. App Store export needs
   an `Apple Distribution` identity (Xcode → Settings → Accounts → Manage
   Certificates → +, or let `-allowProvisioningUpdates` create one when signed
   into a Team Agent/Admin account).
3. **ASC API issuer ID is not recorded anywhere.** The key
   `~/.appstoreconnect/private_keys/AuthKey_6M245PSNS9.p8` is present, but
   `-authenticationKeyIssuerID` needs the issuer UUID, which cannot be derived
   from the key. Get it from App Store Connect → Users and Access →
   Integrations → App Store Connect API (shown at the top of the page).
   **Record it here** so the upload can run unattended next time.

Also discovered and **resolved** 2026-08-11: the boot volume had only 18.5 GB
free (Xcode 26 needs 60–80 GB). Cleared 45 GB of regenerable caches
(`iOS DeviceSupport`, `DerivedData`, unavailable simulators) → **76 GB free**.
No user data touched.

Remaining sequence (mechanics now live in `.claude/skills/continuum-release`):

1. **macOS 15.4.1 → 15.7.9** (3.1 GB, restart). Xcode 26.0–26.3 require macOS
   15.6+; 26.4+ would require Tahoe 26.2, so 15.7.9 + Xcode 26.3 is the cheap
   path and avoids a full Tahoe upgrade.
2. **`xcodes install 26.3`** — needs interactive Apple ID + 2FA.
3. **Issuer UUID** from ASC, then distribution cert via `-allowProvisioningUpdates`.

Once all three are resolved, upload is:

```
xcodebuild -exportArchive \
  -archivePath Continuum-3.4.xcarchive \
  -exportOptionsPlist exportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_6M245PSNS9.p8 \
  -authenticationKeyID 6M245PSNS9 \
  -authenticationKeyIssuerID <ISSUER-UUID>
```

## Known limitation (accepted for 3.3; fixed in 3.4 by the per-day ledger)

- `completedDates` syncs as a single array attribute → **last-writer-wins**
  across devices. Complete Monday on the phone (offline) and Tuesday on the
  iPad, and one write can overwrite the other when both sync. Proper fix is
  one record per completed day (a to-many relationship CloudKit merges
  additively) — a candidate headline for 3.4. Until then, avoid claiming
  "conflict-free" sync in marketing copy.

## App Store metadata

- **What's New:** iCloud sync across devices · complete habits from your
  home/lock screen · year-in-review stats with perfect weeks · streak
  freezes that visibly save your streak · smarter celebrations.
- New screenshots worth taking: stats heatmap, interactive widget, perfect
  week overlay, streak-saved overlay (all very screenshot-able).
- App Privacy: no new data collection (iCloud sync is user's private DB —
  still listed under "Data Not Collected" / not linked to identity).

## Deliberately NOT in 3.3 (keep release small)

- Trophy shelf for graduated habits (next version's headline).
- Widget buttons on lock-screen accessories (display-only there for now).
- Monetization — out for 3.3. Direction as of 2026-09-14: free now, grow,
  then monetize with new premium features (never by gating what's free today).
  Proposed trigger to start: 1,000 weekly active users.
