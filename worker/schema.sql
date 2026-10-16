-- Anonymous usage events. `install` is a random UUID made on the device;
-- nothing ties it to a person. Milestones are sent once per install,
-- `active` at most once per local day.
CREATE TABLE IF NOT EXISTS events (
  install TEXT NOT NULL,
  event   TEXT NOT NULL,
  day     TEXT NOT NULL,          -- device-local YYYY-MM-DD
  version TEXT NOT NULL DEFAULT '',
  ts      INTEGER NOT NULL,       -- server receive time, unix seconds
  PRIMARY KEY (install, event, day)
);

-- What people type into "Send feedback" or the 14-day check-in.
CREATE TABLE IF NOT EXISTS feedback (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  ts      INTEGER NOT NULL,
  kind    TEXT NOT NULL,          -- settings | checkin
  text    TEXT NOT NULL,
  version TEXT NOT NULL DEFAULT '',
  os      TEXT NOT NULL DEFAULT ''
);

-- Once a day per install (3.9+): how many habits and how they're going, as
-- numbers only. `percents` is each habit's consistency sorted high to low
-- (-1 = no number yet), so no value can be matched back to a habit.
CREATE TABLE IF NOT EXISTS snapshots (
  install        TEXT NOT NULL,
  day            TEXT NOT NULL,     -- device-local YYYY-MM-DD
  version        TEXT NOT NULL DEFAULT '',
  habits         INTEGER NOT NULL,
  archived       INTEGER NOT NULL,
  strong         INTEGER NOT NULL,
  overall        INTEGER,           -- pooled %, NULL before anything is done
  percents       TEXT NOT NULL,     -- "92,85,-1"
  done_yesterday INTEGER NOT NULL,
  reminders      INTEGER NOT NULL,
  sort           TEXT NOT NULL,
  ts             INTEGER NOT NULL,
  PRIMARY KEY (install, day)
);
