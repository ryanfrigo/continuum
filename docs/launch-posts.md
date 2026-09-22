# Launch posts — drafts

Post these yourself, from your own account, and answer replies as you. A
founder post written by someone else reads wrong, and these communities are
good at spotting it.

---

## 1. Show HN

**Title:** Show HN: Continuum – a habit tracker that's one 66-day grid

Every habit app I tried wanted an account, a subscription, or both. This one
has neither. You hold a card. A dot fills. That's it.

The grid is 66 days because that's roughly how long a habit takes to become
automatic — Lally et al. (2009) found a median of 66 days, with an enormous
range. Each habit shows that entire window at once, so you see the days you
showed up and the days you didn't.

Eleven months in, it has 83 downloads. That isn't traction and I won't pretend
it is.

Two things I got wrong, in case they're useful:

I shipped iCloud sync as the headline feature in July. It has never worked.
Not once. CloudKit keeps separate Development and Production schemas, I never
deployed the Production one, and when a record type is missing the container
quietly falls back to a local store — no crash, no error, nothing in a review.
I found it last week, by accident, opening the console for something else.

The reminders were worse. Anyone on a 40-day streak got "Day one is waiting."
My streak function counted backwards from today, so it read 0 until you checked
in — which is exactly when the reminder fires. Seven call sites had the same
assumption baked in.

Free, no ads, no IAP, no accounts, iOS 17+.

---

## 2. r/iOSProgramming

**Title:** I shipped iCloud sync 11 months ago. It never synced once.

SwiftData + CloudKit, private database, released July 2026 as the headline
feature of a 3.3 update.

Last week I opened the CloudKit console. Production had no record types at all.
Development had the full schema, and I had simply never clicked Deploy Schema
Changes. `NSPersistentCloudKitContainer` answers a missing record type by
falling back to the local store, so there's no crash and nothing in the logs
unless you go looking for it. Every user had a local-only app advertising sync.

Two things I'd tell anyone shipping CloudKit:

Verify the Production schema itself, not the deploy step on your checklist.
`xcrun cktool export-schema --environment production` takes five seconds and
tells you the truth. My checklist had "deploy schema" on it, unticked, and I
read past it for two months.

`cktool` can write the Development schema but refuses Production — that step is
console-only, by Apple's design.

Separately: `currentStreak()` counted back from today, so it read 0 until the
user checked in. Reminders told 40-day streaks "Day one is waiting." The
graduation animation replayed every single day for anyone past 66. The widget
blanked the streak line each morning. One assumption. Seven call sites.

App is Continuum if you want to look — free, no IAP.

---

## 3. r/SideProject

**Title:** Continuum — habit tracker with no account, no subscription, one 66-day grid

Each habit is a grid of 66 days — roughly how long a behaviour takes to become
automatic. Hold a card to mark the day. That's the app.

No accounts, no ads, no IAP, nothing to buy. I'm not monetising it and haven't
decided whether I ever will.

Honest numbers: live since October 2025, 83 downloads, 4 ratings. Last week I
spent fixing things those four people never complained about. Sync that had
never once worked. Reminders that told long streaks to start over at day one.

iOS 17+. Happy to answer anything about the build.

---

## 4. r/iosapps

**Title:** [Free] Continuum — habit tracker built around a 66-day grid

Free, no IAP, no ads, no account. Hold a habit card to mark the day; a dot
fills on its 66-day grid. Widgets on the home and lock screen mark days done
without opening the app. iCloud sync across devices.

Made it for myself and kept going. iOS 17+.

---

## Where not to post

**r/getdisciplined** and **r/productivity** both ban app promotion outright and
remove it fast. Posting there costs you the account for nothing.

## Practical notes

- One post per day, not four in an hour — simultaneous posting reads as spam
  to both the mods and the algorithms.
- Show HN: weekday, 8–10am US Eastern. Stay at the keyboard for three hours
  afterwards; on HN the comments are the post.
- Lead with the failure story in developer communities. The sync bug is more
  interesting than the app, and people who like the story try the app.
- Don't ask for ratings anywhere. It backfires, and the app now asks at 7 days.
