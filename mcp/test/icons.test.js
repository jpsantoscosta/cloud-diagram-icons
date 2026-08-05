import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadIndex, searchIcons, getIcon, listCategories, listProviders } from '../src/icons.js';

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

test('list_categories and list_providers', () => {
  const cats = listCategories(index, { provider: 'microsoft' });
  assert.ok(cats.length >= 30, `expected 30+ categories, got ${cats.length}`);
  const provs = listProviders(index);
  assert.deepEqual(provs.map((p) => p.provider), ['microsoft']);
});
