// Continuum's only server: anonymous usage events and user feedback.
//
//   POST /event     { install, event, day, version }
//   POST /snapshot  { install, day, version, habits, archived, strong,
//                     overall, percents, done_yesterday, reminders, sort }
//   POST /feedback  { kind, text, version, os }
//   GET  /report    Authorization: Bearer $REPORT_TOKEN   (?since=unix)
//
// Nothing here can identify a person: `install` is a random UUID the app
// makes, and feedback is stored without it.

import { EmailMessage } from "cloudflare:email";

const FROM = "continuum@windowsticker.org"; // a zone with Email Routing on
const EVENTS = new Set(["first_open", "upgrade", "onboarded", "first_habit", "first_completion", "active"]);
const KINDS = new Set(["settings", "checkin"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const PERCENTS = /^(-1|\d{1,3})(,(-1|\d{1,3})){0,49}$/;
const SORTS = new Set(["manual", "mostConsistent", "leastConsistent"]);

const json = (body, status = 200) =>
  new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });

const str = (v, max) => (typeof v === "string" ? v.slice(0, max) : "");
const now = () => Math.floor(Date.now() / 1000);

async function body(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

async function event(request, env) {
  const b = await body(request);
  if (!b || !UUID.test(b.install) || !EVENTS.has(b.event) || !DAY.test(b.day)) {
    return json({ error: "bad event" }, 400);
  }
  await env.DB.prepare(
    "INSERT OR IGNORE INTO events (install, event, day, version, ts) VALUES (?, ?, ?, ?, ?)"
  )
    .bind(b.install.toLowerCase(), b.event, b.day, str(b.version, 20), now())
    .run();
  return new Response(null, { status: 204 });
}

// A small non-negative count, or null if it isn't one.
const count = (v, max = 500) => {
  const n = Number(v);
  return Number.isInteger(n) && n >= 0 && n <= max ? n : null;
};

async function snapshot(request, env) {
  const b = await body(request);
  const habits = count(b?.habits), archived = count(b?.archived), strong = count(b?.strong);
  const done = count(b?.done_yesterday), reminders = count(b?.reminders);
  const overall = b?.overall === "" ? null : count(b?.overall, 100);
  if (!b || !UUID.test(b.install) || !DAY.test(b.day) || !PERCENTS.test(b.percents || "")
      || !SORTS.has(b.sort) || [habits, archived, strong, done, reminders].includes(null)
      || (b.overall !== "" && overall === null)) {
    return json({ error: "bad snapshot" }, 400);
  }
  await env.DB.prepare(
    `INSERT OR REPLACE INTO snapshots
       (install, day, version, habits, archived, strong, overall, percents, done_yesterday, reminders, sort, ts)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(b.install.toLowerCase(), b.day, str(b.version, 20), habits, archived, strong, overall,
          b.percents, done, reminders, b.sort, now())
    .run();
  return new Response(null, { status: 204 });
}

// Latest snapshot per install over the last week, rolled up. Raw rows never
// leave the database through /report.
function habitStats(rows) {
  const n = rows.length;
  if (!n) return { installs: 0 };
  const bucket = (h) => (h <= 3 ? "1-3" : h <= 6 ? "4-6" : h <= 9 ? "7-9" : "10+");
  const habitCounts = { "1-3": 0, "4-6": 0, "7-9": 0, "10+": 0 };
  const perHabit = { new: 0, "0-49": 0, "50-79": 0, "80-100": 0 };
  const sorts = {};
  let habits = 0, strong = 0, archivedUsers = 0, reminderUsers = 0, overallSum = 0, overallN = 0, doneSum = 0;
  for (const r of rows) {
    habitCounts[bucket(r.habits)]++;
    habits += r.habits;
    strong += r.strong;
    doneSum += r.done_yesterday;
    if (r.archived > 0) archivedUsers++;
    if (r.reminders > 0) reminderUsers++;
    if (r.overall !== null) { overallSum += r.overall; overallN++; }
    sorts[r.sort] = (sorts[r.sort] || 0) + 1;
    for (const p of r.percents.split(",").map(Number)) {
      perHabit[p < 0 ? "new" : p < 50 ? "0-49" : p < 80 ? "50-79" : "80-100"]++;
    }
  }
  const round = (x) => Math.round(x * 10) / 10;
  return {
    installs: n,
    habit_counts: habitCounts,
    avg_habits: round(habits / n),
    avg_overall: overallN ? round(overallSum / overallN) : null,
    per_habit: perHabit,
    strong_share: habits ? round((strong / habits) * 100) : null,
    avg_done_yesterday: round(doneSum / n),
    archived_users: archivedUsers,
    reminder_users: reminderUsers,
    sorts,
  };
}

// Best effort: the row in D1 is the record, the email is the nudge.
async function mail(env, kind, text, version, os) {
  if (!env.MAIL || !env.FEEDBACK_TO) return;
  const raw = [
    `From: Continuum <${FROM}>`,
    `To: ${env.FEEDBACK_TO}`,
    `Subject: Continuum feedback (${kind}, ${version || "?"})`,
    `Message-ID: <${crypto.randomUUID()}@windowsticker.org>`,
    `Date: ${new Date().toUTCString()}`,
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=utf-8",
    "Content-Transfer-Encoding: 8bit",
    "",
    text,
    "",
    `-- ${kind} · app ${version || "?"} · iOS ${os || "?"}`,
  ].join("\r\n");
  try {
    await env.MAIL.send(new EmailMessage(FROM, env.FEEDBACK_TO, raw));
  } catch (e) {
    console.log("feedback mail failed", e.message);
  }
}

async function feedback(request, env, ctx) {
  const b = await body(request);
  const text = str(b?.text, 4000).trim();
  if (!b || !KINDS.has(b.kind) || !text) return json({ error: "bad feedback" }, 400);
  await env.DB.prepare(
    "INSERT INTO feedback (ts, kind, text, version, os) VALUES (?, ?, ?, ?, ?)"
  )
    .bind(now(), b.kind, text, str(b.version, 20), str(b.os, 20))
    .run();
  ctx.waitUntil(mail(env, b.kind, text, str(b.version, 20), str(b.os, 20)));
  return new Response(null, { status: 204 });
}

// Funnel per install week, for installs that began on a build with telemetry
// (`first_open`). Upgraders only count toward weekly actives.
const COHORTS = `
  SELECT date(f.day, '-6 days', 'weekday 1') AS week,
    count(*) AS installs,
    sum(EXISTS (SELECT 1 FROM events e WHERE e.install = f.install AND e.event = 'onboarded')) AS onboarded,
    sum(EXISTS (SELECT 1 FROM events e WHERE e.install = f.install AND e.event = 'first_habit')) AS first_habit,
    sum(EXISTS (SELECT 1 FROM events e WHERE e.install = f.install AND e.event = 'first_completion')) AS first_completion,
    sum(julianday('now') - julianday(f.day) >= 7) AS day7_eligible,
    sum(EXISTS (SELECT 1 FROM events e WHERE e.install = f.install AND e.event = 'active'
                AND julianday(e.day) - julianday(f.day) >= 7)) AS active_after_day7
  FROM events f WHERE f.event = 'first_open'
  GROUP BY week ORDER BY week DESC LIMIT 12`;

async function report(request, env) {
  if (!env.REPORT_TOKEN || request.headers.get("authorization") !== `Bearer ${env.REPORT_TOKEN}`) {
    return json({ error: "unauthorized" }, 401);
  }
  const since = Number(new URL(request.url).searchParams.get("since")) || now() - 7 * 86400;
  const [cohorts, active, feedbackRows, snaps] = await env.DB.batch([
    env.DB.prepare(COHORTS),
    env.DB.prepare(
      `SELECT
         count(DISTINCT CASE WHEN ts >= unixepoch() - 7 * 86400 THEN install END) AS last_7d,
         count(DISTINCT CASE WHEN ts >= unixepoch() - 30 * 86400 THEN install END) AS last_30d
       FROM events WHERE event = 'active'`
    ),
    env.DB.prepare("SELECT ts, kind, version, os, text FROM feedback WHERE ts >= ? ORDER BY ts").bind(since),
    env.DB.prepare(
      `SELECT s.* FROM snapshots s
       JOIN (SELECT install, max(day) AS day FROM snapshots
             WHERE ts >= unixepoch() - 7 * 86400 AND version NOT LIKE '%-debug'
             GROUP BY install) latest
       ON s.install = latest.install AND s.day = latest.day`
    ),
  ]);
  return json({
    active_installs: active.results[0],
    cohorts: cohorts.results,
    feedback: feedbackRows.results,
    habit_stats: habitStats(snaps.results),
  });
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);
    if (request.method === "POST" && pathname === "/event") return event(request, env);
    if (request.method === "POST" && pathname === "/snapshot") return snapshot(request, env);
    if (request.method === "POST" && pathname === "/feedback") return feedback(request, env, ctx);
    if (request.method === "GET" && pathname === "/report") return report(request, env);
    return json({ error: "not found" }, 404);
  },
};
