# Consistency first (3.8)

Written 2026-09-29. The goal for this session said not to stop and ask, so this
went straight from design to build without the usual review pause. Push back on
any of it and it changes.

## Why

3.7 made streaks forgiving: one missed day a week is bridged. It's still a
switch, though. Two misses and the number goes to 0, and everything around it
(freezes, a full-screen STREAK SAVED card, an 8pm "streak ends at midnight"
alert) exists to protect that switch.

The app cites Lally et al. (European Journal of Social Psychology, 2009) for its
66 days. The same paper found that missing a single day didn't measurably set
habit formation back. So the app quotes the study and then resets people for
doing exactly what the study says is fine.

The right number already exists. It's the "health" percentage: 10pt text inside
a 32pt ring, beside a streak drawn bigger than it. It's also computed unfairly —
always divided by 66, so a habit done 20 days out of 20 reads 30%.

The name helps here. A continuum is a range; a streak is on or off.

## The number

**Consistency** is the share of the habit's days that you showed up, over the
last 66.

- The window matches the card's grid, today plus the 65 days before it, so the
  number is literally filled squares over squares that have happened.
- Counting starts at the habit's first completed day. Adding a habit on Monday
  and starting it Thursday doesn't cost you three days.
- Today counts once it's done. A day in progress isn't a miss yet.
- No completions at all means no number. The card says "Hold to start".
- Displayed rounded down, so 395 of 396 never reads 100%.
- Frozen days from the old freeze system count as missed. They were.

| History | Shows |
|---|---|
| Started today, done | 100% |
| 20 of the last 20 days | 100% (was 30%) |
| Started 3 days ago, done 2, today pending | 66% |
| Done 60 of the last 65 days, today pending | 92% |

Overall (the header) pools every habit: total days done over total days counted.
That keeps a two-day-old habit at 100% from outvoting a year-old one.

## Trend

The arrow beside a number is that number's change over 7 days: today's value
minus its value 7 days ago with that whole day counted, both as displayed. "↑5" means
the number you're looking at was 5 lower last week.

It needs 7 counted days at the comparison point, so it appears from a habit's
14th day. Zero shows nothing. Down is drawn in grey, never red.

## Where it shows

- **Home header** — pooled consistency, big, with the week's trend and today's
  count ("5 of 6 today"). 3.7 cut the greeting header for being text; this one
  is the metric.
- **Card** — the percentage replaces the ring and the streak row: big number,
  trend, then the grid. Days before a habit's first completion draw fainter than
  misses, so a new habit's grid agrees with its 100%.
- **Stats** — consistency hero, a 12-week bar chart (each bar is one 7-day
  block), then days done, all-time %, best run, perfect weeks, and the year
  heatmap. The streak survives here as "best run".
- **Widgets** — percentage wherever a streak was.
- **Share card** — the percentage is the hero; "DAY STREAK" goes.
- **Settings** — the reorder list shows each habit's percentage.

## Moments

- **Days done.** Milestones at 1, 3, 5, 7, 21, 100 and 365 days done in total,
  in any order. A count that only goes up can't be lost.
- **Habit formed** at 66 days done. Habits already past 66 that never had a
  66-day streak get their graduation on the next completion after updating.
- **Consistency levels.** Reaching 50, 75, 90 or 100%, once a habit has 14
  counted days. Each fires once per habit: the highest level celebrated is
  kept per habit on the device. (The first build looked for a crossing, which
  re-fired every time the denominator wobbled over a line and could never
  reach 100.)
- **Comeback.** Marking today after missing yesterday, on a habit with 3+ days
  done before the gap: "BACK / ON IT". At most once a day across habits and
  once a week per habit, computed from history.
- One tile moment per completion, highest first: milestone, level, comeback.
- Unchanged: perfect day, perfect week, the review prompt (now keyed to days
  done, still at 7 and 21).
- Removed: personal-record streak cards, STREAK SAVED.

## Notifications

Reminder text uses the number and what today does to it ("81%. One hold takes
it to 82."). A habit that missed yesterday gets the existing no-guilt lines.

The 8pm alert becomes **never miss twice**. It fires only on the day after a
miss, when the day before that was done, and not when the habit's reminder is
at 5pm or later. Tomorrow's alert is planned while today is still open; with
today done, the day after tomorrow's is planned instead. Either is removed the
moment its previous day is marked, from the app or the widget. It's far rarer than the
streak alert it replaces, which went off every evening for any 3+ day streak.

## Freezes

Retired. They only protected streaks. Nothing is granted or spent, the
snowflake and STREAK SAVED go, and the model fields stay because CloudKit
schema changes are additive only. No schema change in this release, so no
console deploy.

## Rebrand

- Name: **Continuum: Consistency Tracker** (30/30).
- Subtitle: **Daily habits, no streak resets** (30/30).
- Keywords drop "consistency" (now in the name) and add habit, percent, score.
- Description, promo text and What's New are rewritten around the number.
- In-app: onboarding, walkthrough, About, Settings footers and every milestone
  caption lose streak language. The flame icon goes.

## Screenshots

Five, captured from the running app on an iPhone 16 Pro Max simulator
(1320x2868) with seeded data and a pinned 9:41 status bar, then captioned with
PIL in SF Mono to match the UI:

1. Home with the pooled number: "Miss a day. / nothing resets"
2. Stats, bars climbing: the number getting better week by week
3. A comeback moment in its card
4. Hold to mark the day
5. Habit formed at 66 days done

Caption copy gets finalised against the real captures.

## Testing

Unit tests for the tally, trend, comeback detection, milestones, the
notification planner and app/widget parity, all under the serialized root
suite. Then the app on the 16 Pro Max and a small screen (16e), looking at
every screen touched.

## Not doing

- Submitting to the App Store. That waits for Ryan.
- iPad screenshots.
- A premium tier. The 2026-09-12 direction was free now, monetise later, and
  nothing here should be gated.

## Risks

- Young habits jump (30% → 100%). Honest, but surprising — the release notes
  say so.
- The window slides overnight, so the number can move without you touching it.
  Rolling windows do that. The trend arrow gives it a reason.
- Retiring freezes removes a feature. With 4 ratings and near-zero adoption,
  now is the cheapest moment this will ever be.
