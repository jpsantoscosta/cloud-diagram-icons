import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadIndex, searchIcons, getIcon, listCategories, listProviders, isSafeStyle } from '../src/icons.js';

const STYLE_PREFIX = 'image;aspect=fixed;html=1;points=[];align=center;fontSize=12;';
const stubIndex = (icons) => ({
  ok: true,
  json: async () => ({ provider: 'microsoft', count: icons.length, icons }),
});

// Force the offline fallback (repo root icons.json) so tests are hermetic.
const index = await loadIndex({ fetchImpl: async () => { throw new Error('offline test'); } });

test('index loads from local fallback', () => {
  assert.ok(index.icons.length > 700, `expected 700+ icons, got ${index.icons.length}`);
});

test('exact official name ranks first', () => {
  const hits = searchIcons(index, 'Microsoft Sentinel');
  assert.equal(hits[0].name, 'Microsoft Sentinel');
  assert.equal(hits[0].score, 100);
});

test('shorthand alias resolves: Sentinel', () => {
  const hits = searchIcons(index, 'Sentinel');
  assert.equal(hits[0].name, 'Microsoft Sentinel');
});

test('acronym alias resolves: AKS', () => {
  const hits = searchIcons(index, 'AKS');
  assert.equal(hits[0].name, 'Azure Kubernetes Service');
});

test('legacy name resolves: Azure AD finds Microsoft Entra ID first', () => {
  const hits = searchIcons(index, 'Azure AD');
  assert.equal(hits[0].name, 'Microsoft Entra ID');
});

test('word-boundary matching: Azure AD must not match Azure Advisor', () => {
  const hits = searchIcons(index, 'Azure AD');
  assert.ok(!hits.some((h) => h.name === 'Azure Advisor'), 'Azure Advisor leaked into results');
});

test('style strings are builtin path refs', () => {
  const { icon } = getIcon(index, 'Azure OpenAI');
  assert.equal(icon.ref, 'builtin');
  assert.match(icon.style, /^image;.*image=img\/lib\/azure2\/.+\.svg;$/);
});

test('get_icon by alias', () => {
  const { icon } = getIcon(index, 'ADF');
  assert.equal(icon.name, 'Azure Data Factory');
});

test('get_icon unknown name returns error with no crash', () => {
  const res = getIcon(index, 'Completely Made Up Service');
  assert.ok(res.error);
});

test('provider filter works', () => {
  assert.equal(searchIcons(index, 'AKS', { provider: 'aws' }).length, 0);
  assert.ok(searchIcons(index, 'AKS', { provider: 'microsoft' }).length > 0);
});

test('search collapses entries that resolve to the same shape', () => {
  const dupes = [
    { provider: 'microsoft', category: 'app_services', name: 'Azure App Service', aliases: ['App Service'], w: 68, h: 68, ref: 'builtin', style: `${STYLE_PREFIX}image=img/lib/azure2/app_services/App_Services.svg;`, tags: 'app service' },
    { provider: 'microsoft', category: 'compute', name: 'Azure App Service', aliases: ['App Service'], w: 68, h: 68, ref: 'builtin', style: `${STYLE_PREFIX}image=img/lib/azure2/app_services/App_Services.svg;`, tags: 'app service' },
    { provider: 'microsoft', category: 'web', name: 'Azure App Service', aliases: ['App Service'], w: 68, h: 68, ref: 'builtin', style: `${STYLE_PREFIX}image=img/lib/azure2/web/App_Services.svg;`, tags: 'app service' },
  ];
  const stub = { icons: dupes, count: dupes.length };
  // Two identical styles collapse to one; the third points elsewhere and stays.
  assert.equal(searchIcons(stub, 'Azure App Service').length, 2);
});

test('an alias matching several entries of one shape is not ambiguous', () => {
  const dupes = [
    { provider: 'microsoft', category: 'app_services', name: 'Azure App Service', aliases: ['App Service'], w: 68, h: 68, ref: 'builtin', style: `${STYLE_PREFIX}image=img/lib/azure2/app_services/App_Services.svg;`, tags: '' },
    { provider: 'microsoft', category: 'compute', name: 'Azure App Service', aliases: ['App Service'], w: 68, h: 68, ref: 'builtin', style: `${STYLE_PREFIX}image=img/lib/azure2/app_services/App_Services.svg;`, tags: '' },
  ];
  const res = getIcon({ icons: dupes }, 'App Service');
  assert.equal(res.error, undefined);
  assert.equal(res.icon.name, 'Azure App Service');
});

test('shipped index has no entry repeating both name and style', () => {
  const seen = new Set();
  const repeats = [];
  for (const i of index.icons) {
    const key = `${i.name}|${i.style}`;
    if (seen.has(key)) repeats.push(i.name);
    seen.add(key);
  }
  assert.equal(repeats.length, 0, `repeated: ${[...new Set(repeats)].join(', ')}`);
});

test('isSafeStyle accepts bundled asset paths and inline SVG only', () => {
  assert.ok(isSafeStyle(`${STYLE_PREFIX}image=img/lib/azure2/compute/Kubernetes_Services.svg;`));
  assert.ok(isSafeStyle(`${STYLE_PREFIX}image=data:image/svg+xml,PHN2Zz48L3N2Zz4=;`));
  // External hosts: draw.io fetches these on open, leaking every viewer's IP.
  assert.ok(!isSafeStyle(`${STYLE_PREFIX}image=https://attacker.example/beacon.svg;`));
  assert.ok(!isSafeStyle(`${STYLE_PREFIX}image=//attacker.example/beacon.svg;`));
  assert.ok(!isSafeStyle(`${STYLE_PREFIX}image=img/lib/../../../etc/passwd.svg;`));
  assert.ok(!isSafeStyle(`${STYLE_PREFIX}image=javascript:alert(1);`));
  assert.ok(!isSafeStyle(`${STYLE_PREFIX}fillColor=#fff;`));
  // Upstream asset names legitimately contain parentheses.
  assert.ok(isSafeStyle(`${STYLE_PREFIX}image=img/lib/azure2/other/Cloud_Services_(extended_support).svg;`));
});

test('loadIndex drops entries with external-host styles', async () => {
  const hostile = [
    { provider: 'microsoft', category: 'compute', name: 'Good', w: 48, h: 48, ref: 'builtin', style: `${STYLE_PREFIX}image=img/lib/azure2/compute/Virtual_Machine.svg;` },
    { provider: 'microsoft', category: 'compute', name: 'Beacon', w: 48, h: 48, ref: 'builtin', style: `${STYLE_PREFIX}image=https://attacker.example/beacon.svg;` },
  ];
  const loaded = await loadIndex({ url: 'https://stub.test/icons.json', fetchImpl: async () => stubIndex(hostile) });
  assert.equal(loaded.icons.length, 1);
  assert.equal(loaded.rejected, 1);
  assert.equal(loaded.icons[0].name, 'Good');
  assert.equal(searchIcons(loaded, 'Beacon').length, 0);
});

test('loadIndex refuses an index where nothing is safe', async () => {
  const allHostile = [{ provider: 'microsoft', category: 'compute', name: 'Beacon', w: 48, h: 48, ref: 'builtin', style: `${STYLE_PREFIX}image=https://attacker.example/beacon.svg;` }];
  await assert.rejects(
    loadIndex({ url: 'https://stub.test/icons.json', fetchImpl: async () => stubIndex(allHostile) }),
    /no entries with a safe style/
  );
});

test('every shipped index entry passes the style allowlist', () => {
  const unsafe = index.icons.filter((i) => !isSafeStyle(i.style));
  assert.equal(unsafe.length, 0, `unsafe styles: ${unsafe.map((i) => i.name).join(', ')}`);
});

test('list_categories and list_providers', () => {
  const cats = listCategories(index, { provider: 'microsoft' });
  assert.ok(cats.length >= 30, `expected 30+ categories, got ${cats.length}`);
  const provs = listProviders(index);
  assert.deepEqual(provs.map((p) => p.provider), ['microsoft']);
});
