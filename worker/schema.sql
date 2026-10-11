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
