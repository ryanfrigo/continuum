# App Store listing

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

## Screenshots — still to do

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
