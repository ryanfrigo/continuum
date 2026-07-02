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

1. **Xcode capability sanity check** — open the project once; with automatic
   signing, building to a device registers the App ID capabilities (iCloud/
   CloudKit container `iCloud.com.orionlabs.continuum`, app group, push,
   background modes). All entitlements/Info.plist entries are already in the
   repo — Xcode just needs to sync them to your team.

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

## Known limitation (accepted for 3.3, document — don't advertise around it)

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
- Monetization — deliberately out. Continuum stays a lovable, simple,
  complete habit app.
