#!/usr/bin/env node
// Replace the App Store screenshot set. Uploads new shots first, then removes
// the old ones, so the listing is never left empty mid-run.
//
//   node scripts/asc-screenshots.mjs <dir>            # dry run: show what would change
//   node scripts/asc-screenshots.mjs <dir> --replace  # upload, then delete old
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const KEY_ID = process.env.ASC_KEY_ID || '6M245PSNS9'
const ISSUER = process.env.ASC_ISSUER_ID || '9603f3d8-7877-4300-93fb-f740c62cd44e'
const KEY_PATH = process.env.ASC_KEY_P8 || `${os.homedir()}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8`
const API = 'https://api.appstoreconnect.apple.com'

function token() {
  const key = fs.readFileSync(KEY_PATH, 'utf8')
  const now = Math.floor(Date.now() / 1000)
  const b = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  const h = b({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' })
  const p = b({ iss: ISSUER, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' })
  return `${h}.${p}.` + crypto.sign('sha256', Buffer.from(`${h}.${p}`), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url')
}
async function api(method, p, body) {
  const res = await fetch(`${API}${p}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  })
  const t = await res.text()
  if (!res.ok) throw new Error(`${method} ${p} -> ${res.status}\n${t.slice(0, 400)}`)
  return t ? JSON.parse(t) : {}
}

const dir = process.argv[2]
const replace = process.argv.includes('--replace')
const files = fs.readdirSync(dir).filter((f) => /^\d\d_.*\.png$/.test(f)).sort()
if (!files.length) throw new Error(`No NN_name.png files in ${dir}`)

const app = (await api('GET', '/v1/apps?filter[bundleId]=orion-labs.continuum')).data[0]
const version = (await api('GET', `/v1/apps/${app.id}/appStoreVersions?limit=1`)).data[0]
const locs = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)
const en = locs.data.find((l) => l.attributes.locale === 'en-US')
const sets = await api('GET', `/v1/appStoreVersionLocalizations/${en.id}/appScreenshotSets`)
const set = sets.data.find((s) => s.attributes.screenshotDisplayType === 'APP_IPHONE_67')
const existing = await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`)

console.log(`Version ${version.attributes.versionString} (${version.attributes.appStoreState})`)
console.log(`Existing: ${existing.data.map((s) => s.attributes.fileName).join(', ')}`)
console.log(`Uploading: ${files.join(', ')}`)
if (!replace) {
  console.log('\nDry run. Pass --replace to apply.')
  process.exit(0)
}

const added = []
for (const name of files) {
  const bytes = fs.readFileSync(path.join(dir, name))
  const created = (
    await api('POST', '/v1/appScreenshots', {
      data: {
        type: 'appScreenshots',
        attributes: { fileSize: bytes.length, fileName: name },
        relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } },
      },
    })
  ).data
  for (const op of created.attributes.uploadOperations) {
    const headers = Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value]))
    const chunk = bytes.subarray(op.offset, op.offset + op.length)
    const r = await fetch(op.url, { method: op.method, headers, body: chunk })
    if (!r.ok) throw new Error(`upload chunk failed: ${r.status}`)
  }
  await api('PATCH', `/v1/appScreenshots/${created.id}`, {
    data: {
      type: 'appScreenshots',
      id: created.id,
      attributes: { uploaded: true, sourceFileChecksum: crypto.createHash('md5').update(bytes).digest('hex') },
    },
  })
  added.push(created.id)
  console.log(`  uploaded ${name}`)
}

for (const old of existing.data) {
  await api('DELETE', `/v1/appScreenshots/${old.id}`)
  console.log(`  removed ${old.attributes.fileName}`)
}
await api('PATCH', `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
  data: added.map((id) => ({ type: 'appScreenshots', id })),
})
console.log(`\nSet now has ${added.length} screenshots, in order.`)
