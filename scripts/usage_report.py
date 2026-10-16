#!/usr/bin/env python3
"""Print Continuum's own usage numbers from the continuum-api Worker.

    python3 scripts/usage_report.py            # funnel, actives, habit stats, feedback text
    python3 scripts/usage_report.py --counts   # no feedback text (public CI logs)

Token: $CONTINUUM_REPORT_TOKEN, else ~/.config/continuum/report_token.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import sys
import urllib.request

URL = "https://continuum-api.orion-labs.workers.dev/report"


def token() -> str:
    if t := os.environ.get("CONTINUUM_REPORT_TOKEN"):
        return t
    return open(os.path.expanduser("~/.config/continuum/report_token")).read().strip()


def main() -> None:
    counts_only = "--counts" in sys.argv
    req = urllib.request.Request(URL, headers={"Authorization": f"Bearer {token()}", "User-Agent": "continuum-usage-report"})
    r = json.load(urllib.request.urlopen(req, timeout=30))

    a = r["active_installs"]
    print(f"Active installs: {a['last_7d']} in the last 7 days, {a['last_30d']} in the last 30\n")

    print("New installs by week (Monday). Each column is a count of those installs.")
    print(f"{'week':<12}{'installs':>9}{'onboarded':>10}{'habit':>7}{'done':>6}{'d7 back':>12}")
    for c in r["cohorts"]:
        back = f"{c['active_after_day7']}/{c['day7_eligible']}" if c["day7_eligible"] else "-"
        print(f"{c['week']:<12}{c['installs']:>9}{c['onboarded']:>10}{c['first_habit']:>7}"
              f"{c['first_completion']:>6}{back:>12}")
    if not r["cohorts"]:
        print("(none yet: only installs on 3.8.1+ count)")

    h = r.get("habit_stats") or {}
    print("\nHabits (latest daily snapshot per install, last 7 days; 3.9+ only)")
    if not h.get("installs"):
        print("(none yet)")
    else:
        c = h["habit_counts"]
        print(f"  installs reporting: {h['installs']}   avg habits: {h['avg_habits']}")
        print(f"  habits per install: 1-3: {c['1-3']}   4-6: {c['4-6']}   7-9: {c['7-9']}   10+: {c['10+']}")
        p = h["per_habit"]
        print(f"  each habit's %:     80-100: {p['80-100']}   50-79: {p['50-79']}   0-49: {p['0-49']}   new: {p['new']}")
        print(f"  avg overall: {h['avg_overall']}%   strong: {h['strong_share']}% of habits"
              f"   avg done yesterday: {h['avg_done_yesterday']}")
        print(f"  archiving: {h['archived_users']}   reminders on: {h['reminder_users']}   sort: {h['sorts']}")

    fb = r["feedback"]
    print(f"\nFeedback in the last 7 days: {len(fb)}")
    if counts_only:
        return
    for f in fb:
        when = dt.datetime.fromtimestamp(f["ts"]).strftime("%Y-%m-%d %H:%M")
        print(f"\n[{when} · {f['kind']} · {f['version']} · iOS {f['os']}]\n{f['text']}")


if __name__ == "__main__":
    main()
