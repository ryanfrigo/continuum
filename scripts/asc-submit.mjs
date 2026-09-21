#!/usr/bin/env node
// Create an App Store version, attach a build, turn on phased release, and
// submit for review — the steps release.yml deliberately stops short of.
//
//   node scripts/asc-submit.mjs --version 3.5 --build 6            # prepare only
//   node scripts/asc-submit.mjs --version 3.5 --build 6 --submit   # and submit
//
// Prepare is idempotent and reversible in App Store Connect. --submit is the
// one that reaches Apple; run prepare first and read what it printed.
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'

const KEY_ID = process.env.ASC_KEY_ID || '6M245PSNS9'
const ISSUER = process.env.ASC_ISSUER_ID || '9603f3d8-7877-4300-93fb-f740c62cd44e'
const KEY_PATH = process.env.ASC_KEY_P8 || `${os.homedir()}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8`
const BUNDLE_ID = 'orion-labs.continuum'
const API = 'https://api.appstoreconnect.apple.com'

const arg = (name, fallback = null) => {
  const i = process.argv.indexOf(`--${name}`)
  return i === -1 ? fallback : process.argv[i + 1]
}
const wants = (name) => process.argv.includes(`--${name}`)

function token() {
  const key = fs.readFileSync(KEY_PATH, 'utf8')
  const now = Math.floor(Date.now() / 1000)
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  const head = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' })
  const body = b64({ iss: ISSUER, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' })
  const sig = crypto
    .sign('sha256', Buffer.from(`${head}.${body}`), { key, dsaEncoding: 'ieee-p1363' })
    .toString('base64url')
  return `${head}.${body}.${sig}`
}

async function api(method, path, body) {
  const res = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  })
  const text = await res.text()
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status}\n${text.slice(0, 900)}`)
  return text ? JSON.parse(text) : {}
}

const versionString = arg('version', '3.5')
const buildNumber = arg('build', '6')
const whatsNewFile = arg('whats-new', 'scripts/whats-new.txt')

const app = (await api('GET', `/v1/apps?filter[bundleId]=${BUNDLE_ID}`)).data[0]
if (!app) throw new Error(`No app for bundle ${BUNDLE_ID}`)
console.log(`App: ${app.attributes.name} (${app.id})`)

// The build must exist and have finished processing, or the attach silently
// leaves the version buildless and review bounces it.
const builds = await api(
  'GET',
  `/v1/builds?filter[app]=${app.id}&limit=20&sort=-uploadedDate&include=preReleaseVersion`
)
const build = builds.data.find(
  (b) =>
    b.attributes.version === String(buildNumber) &&
    builds.included?.find((i) => i.id === b.relationships.preReleaseVersion.data.id)?.attributes
      .version === versionString
)
if (!build) {
  const seen = builds.data.map((b) => b.attributes.version).join(', ')
  throw new Error(`Build ${versionString} (${buildNumber}) not found. Recent builds: ${seen}`)
}
console.log(`Build: ${versionString} (${buildNumber}) — ${build.attributes.processingState}`)
if (build.attributes.processingState !== 'VALID') {
  throw new Error(`Build is ${build.attributes.processingState}, not VALID yet. Wait for processing.`)
}

// Reuse an existing editable version if there is one
const existing = (
  await api('GET', `/v1/apps/${app.id}/appStoreVersions?filter[versionString]=${versionString}&limit=1`)
).data[0]
let version = existing
if (version) {
  console.log(`Version ${versionString} already exists (${version.attributes.appStoreState})`)
} else {
  version = (
    await api('POST', '/v1/appStoreVersions', {
      data: {
        type: 'appStoreVersions',
        attributes: { platform: 'IOS', versionString, releaseType: 'AFTER_APPROVAL' },
        relationships: { app: { data: { type: 'apps', id: app.id } } },
      },
    })
  ).data
  console.log(`Created version ${versionString} (${version.id})`)
}

// What's New
if (fs.existsSync(whatsNewFile)) {
  const whatsNew = fs.readFileSync(whatsNewFile, 'utf8').trim()
  const locs = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)
  for (const loc of locs.data.filter((l) => l.attributes.locale.startsWith('en'))) {
    await api('PATCH', `/v1/appStoreVersionLocalizations/${loc.id}`, {
      data: { type: 'appStoreVersionLocalizations', id: loc.id, attributes: { whatsNew } },
    })
    console.log(`Set What's New for ${loc.attributes.locale} (${whatsNew.length} chars)`)
  }
}

await api('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, {
  data: { type: 'builds', id: build.id },
})
console.log('Attached build')

// Phased release: a bug reaches 1% on day one instead of everyone
try {
  await api('POST', '/v1/appStoreVersionPhasedReleases', {
    data: {
      type: 'appStoreVersionPhasedReleases',
      attributes: { phasedReleaseState: 'INACTIVE' },
      relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
    },
  })
  console.log('Phased release: ON')
} catch (e) {
  // Already present from a previous run
  console.log(`Phased release: already set (${String(e).split('\n')[0]})`)
}

if (!wants('submit')) {
  console.log('\nPrepared, NOT submitted. Re-run with --submit to send it to Apple.')
  process.exit(0)
}

const submission = (
  await api('POST', '/v1/reviewSubmissions', {
    data: {
      type: 'reviewSubmissions',
      attributes: { platform: 'IOS' },
      relationships: { app: { data: { type: 'apps', id: app.id } } },
    },
  })
).data
await api('POST', '/v1/reviewSubmissionItems', {
  data: {
    type: 'reviewSubmissionItems',
    relationships: {
      reviewSubmission: { data: { type: 'reviewSubmissions', id: submission.id } },
      appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
    },
  },
})
await api('PATCH', `/v1/reviewSubmissions/${submission.id}`, {
  data: { type: 'reviewSubmissions', id: submission.id, attributes: { submitted: true } },
})
const after = await api('GET', `/v1/appStoreVersions/${version.id}`)
console.log(`\nSubmitted. Version state: ${after.data.attributes.appStoreState}`)
