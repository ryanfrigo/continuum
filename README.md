# Continuum

An iOS habit tracker built around one number per habit: the share of days you
showed up, over the last 66. Miss a day and it dips a point or two. It never
resets to zero.

On the App Store as **Continuum: Consistency Tracker** (app id 6754441151).
Free, with no account and no ads.

## How it works

- **Consistency** is days done over days counted, in a window that matches the
  66-day grid on every card. Counting starts at a habit's first done day, and
  today only counts once it's done. The maths lives in `HabitMath`
  (`Shared/HabitDataManager.swift`), which the app and the widget both use.
- The arrow beside a number is its change over the last 7 days.
- A habit is **formed** at 66 days done, in any order. Lally et al. (2009)
  found a median of 66 days to automaticity, and that one missed day didn't set
  it back.
- Hold a card to mark today. Tap once, then hold, to fill in yesterday.
- One reminder per habit, sent only if it isn't done yet, plus a single 8pm
  nudge on the evening after a miss.

Streaks still exist — the stats screen shows the current and best run — but
nothing is built on them any more. 3.8 retired streak freezes.

## Stack

SwiftUI, SwiftData with CloudKit sync (private database), WidgetKit with an
interactive AppIntent, Swift Testing. iOS 17+, built with the iOS 26 SDK or
later.

## Build and test

```bash
xcodebuild test -scheme continuum -testPlan continuum \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

The tests run serialized because they share a global calendar seam. Releases
go through CI (`.github/workflows/release.yml`); the runbook is
`.claude/skills/continuum-release/SKILL.md`.

## Screenshots

`AppStoreScreenshots/3.8/` holds the current App Store set, captured from the
app with the data in `continuumTests/SeedShots.swift` and captioned by
`scripts/caption-screenshots.py`.
