#!/usr/bin/env python3
"""Read Continuum's App Store numbers from the App Store Connect API.

Downloads and retention do not need an analytics SDK in the app — Apple
already has them. This asks for the reports, then prints totals.

Apple generates analytics reports asynchronously: the first run creates the
request and exits with "not ready yet", a later run reads it. Reports arrive
within a day or so, then refresh daily.

Env:
  ASC_KEY_ID     App Store Connect API key id
  ASC_ISSUER_ID  issuer UUID (in CI as a repo secret)
  ASC_KEY_PATH   path to AuthKey_<id>.p8
  ASC_APP_ID     numeric app id (default: Continuum)
"""
from __future__ import annotations

import collections
import csv
import datetime as dt
import gzip
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt  # PyJWT + cryptography

API = "https://api.appstoreconnect.apple.com"
APP_ID = os.environ.get("ASC_APP_ID", "6754441151")
# Substrings of the report names worth pulling. Apple's exact names change;
# matching loosely beats hardcoding a name that quietly stops matching.
WANTED = ("installation", "download", "retention", "session")


def token() -> str:
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key = open(os.environ["ASC_KEY_PATH"]).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def api(path: str, method: str = "GET", body: dict | None = None) -> dict:
    url = path if path.startswith("http") else f"{API}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        detail = e.read().decode()[:600]
        raise SystemExit(f"ASC API {method} {url} -> {e.code}\n{detail}")


def paged(path: str) -> list[dict]:
    out, url = [], path
    while url:
        page = api(url)
        out.extend(page.get("data", []))
        url = page.get("links", {}).get("next")
    return out


def ensure_request() -> str:
    """Return an analytics report request id, creating a snapshot if needed."""
    existing = paged(f"/v1/apps/{APP_ID}/analyticsReportRequests?limit=200")
    for req in existing:
        attrs = req["attributes"]
        if attrs.get("accessType") == "ONE_TIME_SNAPSHOT" and not attrs.get("stoppedDueToInactivity"):
            return req["id"]
    created = api(
        "/v1/analyticsReportRequests",
        "POST",
        {
            "data": {
                "type": "analyticsReportRequests",
                # accessType is the only writable attribute here; sending a
                # name gets a 409 ENTITY_ERROR.ATTRIBUTE.UNKNOWN.
                "attributes": {"accessType": "ONE_TIME_SNAPSHOT"},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        },
    )
    print("Created a new report request; Apple usually has data within a day. Re-run then.")
    return created["data"]["id"]


def rows_for(report_id: str, limit_instances: int = 40) -> list[dict]:
    """Newest daily instances of one report, parsed from their gzipped TSVs."""
    instances = paged(f"/v1/analyticsReports/{report_id}/instances?filter[granularity]=DAILY&limit=200")
    instances.sort(key=lambda i: i["attributes"].get("processingDate", ""), reverse=True)
    rows: list[dict] = []
    for inst in instances[:limit_instances]:
        for seg in paged(f"/v1/analyticsReportInstances/{inst['id']}/segments"):
            url = seg["attributes"]["url"]
            with urllib.request.urlopen(url) as resp:
                raw = resp.read()
            text = gzip.decompress(raw).decode("utf-8", "replace")
            rows.extend(csv.DictReader(io.StringIO(text), delimiter="\t"))
    return rows


def summarize(name: str, rows: list[dict]) -> None:
    if not rows:
        print(f"  {name}: no rows yet")
        return
    date_col = next((c for c in rows[0] if c.strip().lower() == "date"), None)
    count_col = next((c for c in rows[0] if c.strip().lower() in ("counts", "count", "quantity")), None)
    if not (date_col and count_col):
        print(f"  {name}: columns = {list(rows[0])[:8]}")
        return

    type_col = next((c for c in rows[0] if "download type" in c.strip().lower()), None)
    by_day: dict[str, int] = collections.defaultdict(int)
    for r in rows:
        if type_col and "first" not in (r.get(type_col) or "").lower():
            continue  # first-time downloads, not redownloads or updates
        try:
            by_day[r[date_col]] += int(float(r[count_col] or 0))
        except ValueError:
            continue

    today = dt.date.today()

    def total(days: int) -> int:
        cutoff = today - dt.timedelta(days=days)
        return sum(v for d, v in by_day.items() if _date(d) and _date(d) >= cutoff)

    print(f"  {name}: {sum(by_day.values())} total across {len(by_day)} days"
          f" | 30d {total(30)} | 90d {total(90)} | 7d {total(7)}")
    for day in sorted(by_day)[-7:]:
        print(f"      {day}  {by_day[day]}")


def _date(value: str):
    try:
        return dt.date.fromisoformat(value.strip()[:10])
    except ValueError:
        return None


def main() -> None:
    app = api(f"/v1/apps/{APP_ID}")["data"]["attributes"]
    print(f"App: {app.get('name')} ({app.get('bundleId')})")

    request_id = ensure_request()
    reports = paged(f"/v1/analyticsReportRequests/{request_id}/reports?limit=200")
    if not reports:
        print("No reports generated yet. Re-run this tomorrow.")
        return

    print(f"{len(reports)} reports available:")
    for report in reports:
        name = report["attributes"].get("name", "?")
        if not any(w in name.lower() for w in WANTED):
            continue
        summarize(name, rows_for(report["id"]))


if __name__ == "__main__":
    sys.exit(main())
