# App Store listing

## 3.8: the consistency rebrand (2026-09-29)

The app stopped being about streaks, so the listing had to stop saying
"Habit Streak Grid". A continuum is a range and a streak is on or off, so the
name was arguing with the app all along.

| Field | Value | Chars |
|---|---|---|
| Name | Continuum: Consistency Tracker | 30/30 |
| Subtitle | Daily habits, no streak resets | 30/30 |
| Keywords | percent,score,minimal,dark,widget,66,discipline,routine,progress,heatmap,checklist,ritual,goal,dot | 98/100 |

"Consistency tracker" is a query with clear intent and almost no competition.
"Streak" stays in the subtitle on purpose: the people most likely to want this
app are searching for streak trackers after one of them reset on them.
"Consistency" left the keyword field because it's in the name now.

Screenshots (`AppStoreScreenshots/3.8/`, five, 1320x2868):

1. `01_consistency.png`: home with the pooled 82%. "Miss a day. / Nothing resets."
2. `02_never_miss_twice.png`: a comeback in its card. "Missed yesterday? / Don't miss twice."
3. `03_week_by_week.png`: stats, 12 bars climbing. "12 weeks. / Watch it climb."
4. `04_66_days.png`: graduation. "66 days. / Not in a row."
5. `05_hold.png`: mid-hold, magnified. "Hold to mark / the day."

To rebuild them: run `seedForScreenshots()` (or `seedForGraduationScreenshot()`)
from `continuumTests/SeedShots.swift` on the iPhone 16 Pro Max simulator,
capture with a 9:41 status bar, then
`python3 scripts/caption-screenshots.py <raw dir> AppStoreScreenshots/3.8`.
The raw captures are in `AppStoreScreenshots/3.8/raw/`. Xcode 27 has no
Simulator.app; DeviceHub shows the screen and takes clicks, but roughly one in
two gets dropped, so check every capture.

Apply with `node scripts/asc-metadata.mjs --apply` and
`node scripts/asc-screenshots.mjs AppStoreScreenshots/3.8 --replace` while 3.8
is PREPARE_FOR_SUBMISSION, before it goes to review — screenshots are locked
once it's waiting.

## 3.5 listing (2026-09-21)

Researched 2026-09-21, against real numbers: 83 first-time downloads lifetime,
14 in the last 30 days, 4 ratings at 5.0. The listing had never been optimised.

## What was wrong

- **Characters spent twice.** Apple indexes name + subtitle + keyword field as
  one pool. "habit" and "streak" sat in both the name and the keywords.
- **Chasing a term we cannot win.** "habit tracker" has ~67/100 difficulty and
  the top 9 results average 115,314 ratings. Continuum has 4. Ranking takes
  download velocity and ratings, so the head term is structurally out of reach.
- **A generic subtitle.** "Build Lasting Habits" is prime indexed space that
  targeted nothing.
- **Stale claims.** The description sold "full-screen animated rewards" (moved
  into the habit card in 3.5) and listed a 30-day milestone that doesn't exist.

## What we're shipping (`scripts/aso.json`)

| Field | Value | Chars |
|---|---|---|
| Name | Continuum: Habit Streak Grid | 28/30 |
| Subtitle | Daily Routine & Goal Tracker | 28/30 |
| Keywords | minimal,dark,widget,checklist,consistency,discipline,ritual,66,day,journal,progress,reminder,log,dot | 100/100 |

The strategy is to own distinctive atoms rather than compete for head terms:
`minimal`, `dark`, `widget`, `66`, `dot`. Apple auto-combines keywords into
phrases, so these buy "minimal habit tracker", "dark habit widget", "66 day
habit", "habit streak grid" — low volume, near-zero competition, and the app is
genuinely the right answer for each.

## Applying it

```bash
node scripts/asc-metadata.mjs            # show current vs staged
node scripts/asc-metadata.mjs --promo    # promotional text — works any time
node scripts/asc-metadata.mjs --apply    # the rest — needs an editable version
```

Name, subtitle, keywords and description are **locked while a version is in
review**. `--apply` refuses unless the version is `PREPARE_FOR_SUBMISSION`, so
run it on the next version after 3.5 clears. Promotional text was applied
2026-09-21 while 3.5 sat in review.

## Screenshots — done 2026-09-21

Replaced. Five of the six were onboarding pages; the listing sold the tutorial
rather than the app. The set is now three, captured from the running app on an
iPhone 16 Pro Max simulator (1320x2868) and captioned in Menlo to match the UI:

1. `01_grid.png` — six habits, full 66-day grids. "66 days. / one dot at a time"
2. `02_hold.png` — the hold-to-complete affordance. "Hold to mark done. / harder to do by accident"
3. `03_milestone.png` — a 21-day milestone inside its card. "Milestones land / in the card, not over it"

Sources are in `AppStoreScreenshots/3.5/`. Upload with
`node scripts/asc-screenshots.mjs <dir> --replace` (adds the new set before
deleting the old, so the listing is never empty).

**Apple accepts text metadata edits while a version is WAITING_FOR_REVIEW but
refuses screenshot changes** ("Can't Create Screenshot while Waiting For
Review"). Changing screenshots means cancelling the review submission
(`PATCH /v1/reviewSubmissions/{id} {canceled:true}`), uploading, and
resubmitting — which costs the queue position. Do screenshots before submitting.

## Old brief (kept for the shots not yet taken)

Six exist, 6.7" iPhone only, no iPad set (while the description promises iPad
sync). They still show the full-screen celebrations 3.5 replaced. The first
three are also OCR-indexed, so they are keyword space as well as conversion.

1. One habit, one grid, filled to ~day 41, full-bleed, no device frame.
   Caption: "66 days. One dot at a time."
2. Mid-hold: thumb on a card, progress partway, dot about to fill.
   Caption: "Hold to mark done."
3. Lock screen widget with mark-done. Caption: "Mark it from the lock screen."

## The honest ceiling

Perfect ASO with no other marketing gets this app to an estimated 30–120
downloads/month — 2–8× current, and not a business. The binding constraint is a
loop: ranking needs velocity and ratings, velocity needs ranking, and 4 ratings
is below the floor where the algorithm treats the app as a real result. ASO
closes perhaps 30% of the gap and permanently raises the floor for one hour of
work. The other 70% is one external velocity injection that converts into
50–100 ratings, after which this same metadata is worth several times more.
