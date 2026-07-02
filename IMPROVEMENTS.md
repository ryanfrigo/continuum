# Continuum v3.3 — Sync, Interactive Widget, Stats, Timezone Safety

Four improvements built on branchless working tree (see git note below).
No public API was removed; all existing views compile against the new model.

## 1. Timezone-safe streak storage (the silent streak-killer, fixed)

**The bug:** days were stored as midnight-local timestamps. Reading them in a
different timezone (travel, even DST in edge cases) shifted history by a day
and broke streaks. Classic habit-app 1-star review generator.

**The fix:** a calendar day is now canonically stored as **12:00:30 UTC** and
compared via integer day keys (`20260612`). Reads are exact in every timezone.
(The :30-second marker is what distinguishes canonical dates from legacy
midnight-local ones — plain noon UTC collides with local midnight in UTC+12
zones like New Zealand, which would have shifted that history by a day.)

- `Shared/HabitDataManager.swift` → new `ContinuumDay` + `HabitMath` (shared
  with the widget so app and widget always agree).
- `Habit.migrateToCanonicalStorage()` runs on every launch (idempotent, cheap)
  and rewrites legacy dates. Existing users' history is preserved.
- Algorithm verified against 13 scenarios (NY→Honolulu travel, Tokyo→Honolulu,
  DST spring-forward, leap years, +14/-12 extreme zones). All pass.

**Bonus bug fix:** streak freezes previously did nothing visible — `currentStreak()`
ignored frozen days. Frozen days now bridge AND count, in app and widget.

## 2. iCloud sync (SwiftData + CloudKit)

- `Habit` model is CloudKit-compatible (no `.unique`, defaults everywhere).
- `continuumApp` builds a CloudKit container (`iCloud.com.orionlabs.continuum`)
  with automatic fallback to local-only if unavailable — never crashes, never
  blocks on iCloud status.
- CloudKit can deliver duplicate habits (no unique constraints) →
  `ContentView.dedupeHabits()` merges by id, unioning histories. No data loss.
- `continuum.entitlements` updated with iCloud keys.

## 3. Interactive widget + lock screen widgets

- `ToggleHabitIntent` (AppIntents): tap MARK DONE on the widget — no app launch.
  Widget updates its snapshot instantly and queues the change; the app
  reconciles into SwiftData on next activation (and still fires celebrations).
- Small + medium widgets now have completion buttons.
- New lock screen families: circular (health ring + streak) and rectangular.
- **Pre-existing bug fixed:** `-DWIDGET_EXTENSION` was only set for Debug —
  Release/Archive builds of the widget could not compile. Added to Release.

## 4. Stats view (year heatmap)

- Long-press a habit card → **View Stats**: GitHub-style 365-day heatmap
  (freeze days shown in cyan), current/longest streak, total days, 66-day
  health, graduation badge, share button. Matches the dark monospace brand.
- New file: `continuum/Views/HabitStatsView.swift` (picked up automatically —
  project uses synchronized groups).

## 5. Real unit tests

`continuumTests/continuumTests.swift` (was an empty stub): 25+ assertions
across day-key math, streaks, freezes, graduation, widget parity, dedupe
merging, and the four timezone scenarios that motivated the rewrite.

---

## What YOU need to do in Xcode (one-time, ~3 min)

1. **Clean stale git locks** (sandbox couldn't delete them):
   ```
   rm -f continuum/.git/HEAD.lock continuum/.git/index.lock continuum/.git/objects/maintenance.lock
   ```
   Your pre-change state is committed as `bec4633`. Review my changes with
   `git diff`, then commit (a branch is optional — locks blocked branch creation).

2. **Enable iCloud capability:** target `continuum` → Signing & Capabilities →
   `+ Capability` → iCloud → check **CloudKit** → add container
   `iCloud.com.orionlabs.continuum`. (Entitlements file is already updated;
   Xcode just needs to register the container with your team.)

3. **Optional but recommended:** `+ Capability` → Background Modes → check
   **Remote notifications** (makes CloudKit sync push-fresh instead of
   launch-time only).

4. **Run the tests:** Cmd+U. Then build to a device and test:
   - Existing data still shows correct streaks (migration).
   - Widget MARK DONE → open app → completion + celebration appear.
   - Settings → iCloud account on second device/simulator → habits appear.

## Release suggestions

- Ship as 3.3. Phased release ON — this touches the data layer.
- App Store "What's New": iCloud sync + complete from your home/lock screen +
  year-in-review stats. All three are user-visible selling points.
- The monetization seam later: streak freezes, habit cap, and stats are the
  natural premium tier — the architecture now supports gating any of them.
