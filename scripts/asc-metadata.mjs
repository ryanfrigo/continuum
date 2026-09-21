#!/usr/bin/env node
// Apply the ASO package in scripts/aso.json to App Store Connect.
//
//   node scripts/asc-metadata.mjs                 # show current vs staged
//   node scripts/asc-metadata.mjs --promo         # promotional text only (no review needed)
//   node scripts/asc-metadata.mjs --apply         # name, subtitle, keywords, description too
//
// Name/subtitle/keywords/description are locked while a version is in review;
// --apply needs an editable version (PREPARE_FOR_SUBMISSION). Promotional text
// is the one field Apple lets you change any time.
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'

const KEY_ID = process.env.ASC_KEY_ID || '6M245PSNS9'
const ISSUER = process.env.ASC_ISSUER_ID || '9603f3d8-7877-4300-93fb-f740c62cd44e'
const KEY_PATH = process.env.ASC_KEY_P8 || `${os.homedir()}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8`
const API = 'https://api.appstoreconnect.apple.com'
const has = (f) => process.argv.includes(`--${f}`)

function token() {
  const key = fs.readFileSync(KEY_PATH, 'utf8')
  const now = Math.floor(Date.now() / 1000)
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  const h = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' })
  const p = b64({ iss: ISSUER, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' })
  const sig = crypto.sign('sha256', Buffer.from(`${h}.${p}`), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url')
  return `${h}.${p}.${sig}`
}
async function api(method, path, body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  })
  const t = await res.text()
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status}\n${t.slice(0, 500)}`)
  return t ? JSON.parse(t) : {}
}

const aso = JSON.parse(fs.readFileSync('scripts/aso.json', 'utf8'))
const app = (await api('GET', '/v1/apps?filter[bundleId]=orion-labs.continuum')).data[0]

// Name and subtitle live on appInfo; keywords/description/promo on the version.
const infos = await api('GET', `/v1/apps/${app.id}/appInfos`)
const editableInfo = infos.data.find((i) => i.attributes.appStoreState !== 'READY_FOR_SALE')
const version = (await api('GET', `/v1/apps/${app.id}/appStoreVersions?limit=1`)).data[0]
const vLocs = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)
const vEn = vLocs.data.find((l) => l.attributes.locale === 'en-US')

console.log(`Version ${version.attributes.versionString} — ${version.attributes.appStoreState}`)
console.log(`\n            CURRENT                              STAGED`)
console.log(`keywords    ${vEn.attributes.keywords}\n            -> ${aso.keywords}`)

if (has('promo') || has('apply')) {
  await api('PATCH', `/v1/appStoreVersionLocalizations/${vEn.id}`, {
    data: { type: 'appStoreVersionLocalizations', id: vEn.id, attributes: { promotionalText: aso.promotionalText } },
  })
  console.log('\n✅ promotional text updated')
}

if (has('apply')) {
  if (version.attributes.appStoreState !== 'PREPARE_FOR_SUBMISSION') {
    console.log(`\n⚠️  Version is ${version.attributes.appStoreState}; name/subtitle/keywords/description are locked.`)
    console.log('   Run --apply once a version is editable again.')
    process.exit(1)
  }
  await api('PATCH', `/v1/appStoreVersionLocalizations/${vEn.id}`, {
    data: {
      type: 'appStoreVersionLocalizations',
      id: vEn.id,
      attributes: { keywords: aso.keywords, description: aso.description },
    },
  })
  const iLocs = await api('GET', `/v1/appInfos/${editableInfo.id}/appInfoLocalizations`)
  const iEn = iLocs.data.find((l) => l.attributes.locale === 'en-US')
  await api('PATCH', `/v1/appInfoLocalizations/${iEn.id}`, {
    data: { type: 'appInfoLocalizations', id: iEn.id, attributes: { name: aso.name, subtitle: aso.subtitle } },
  })
  console.log('✅ name, subtitle, keywords and description updated')
}
