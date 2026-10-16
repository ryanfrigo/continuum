#!/usr/bin/env python3
"""SessionStart hook: once a week, pull the usage + feedback report into the
Claude session so new feedback gets read without anyone asking.

Silent (no output) until 7 days have passed since the last run. Reads nothing
but what scripts/usage_report.py reads (the report token in ~/.config), and
prints only to the local session — never run this in CI, the repo is public.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

STAMP = Path.home() / ".config" / "continuum" / "last_feedback_check"
WEEK = 7 * 86_400
REPO = Path(__file__).resolve().parent.parent


def main() -> None:
    if STAMP.exists() and time.time() - STAMP.stat().st_mtime < WEEK:
        return
    try:
        out = subprocess.run(
            [sys.executable, str(REPO / "scripts" / "usage_report.py")],
            capture_output=True, text=True, timeout=45, cwd=REPO,
        )
    except subprocess.TimeoutExpired:
        return
    if out.returncode != 0:
        return  # offline or no token: try again next session
    STAMP.parent.mkdir(parents=True, exist_ok=True)
    STAMP.touch()
    report = out.stdout.strip()
    print(json.dumps({
        "systemMessage": "Weekly Continuum usage + feedback report loaded.",
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": (
                "Weekly Continuum check (runs once every 7 days). Summarise this "
                "for Ryan at the start of your first reply: new feedback first "
                "(skip his own 'Test' messages), then installs and the funnel.\n\n"
                + report
            ),
        },
    }))


if __name__ == "__main__":
    main()
