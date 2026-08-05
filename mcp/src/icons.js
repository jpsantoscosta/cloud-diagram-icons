// Icon index loading and lookup. Pure logic, no MCP wiring, so it is unit
// testable and reusable.

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const DEFAULT_INDEX_URL =
  'https://raw.githubusercontent.com/jpsantoscosta/cloud-diagram-icons/main/icons.json';

// Bundled snapshot (copied in at pack time); repo checkout falls back to the
// repo root copy one level up.
const SNAPSHOT_CANDIDATES = [
  path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data', 'icons.json'),
  path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'icons.json'),
];

// The index is fetched over the network and its style strings are pasted
// verbatim into diagrams, so it is untrusted input. draw.io fetches whatever
// host appears in `image=`, which would turn a tampered index into a tracking
// beacon firing for everyone who opens the diagram. Only two shapes are ever
// legitimate: a relative path into draw.io's own bundled assets, or an inline
// SVG data URI.
// Upstream asset names include characters like parentheses, so the path rule
// is deliberately tolerant on naming while strict on the properties that
// matter: it must stay under img/lib/, it cannot carry a scheme (no ":"), it
// cannot go protocol-relative ("//"), and it cannot traverse ("..").
const BUILTIN_IMAGE = /^img\/lib\/[A-Za-z0-9_./()+ -]+\.svg$/;
const EMBEDDED_IMAGE = /^data:image\/svg\+xml,[A-Za-z0-9+/=]+$/;

/** True when a style's image reference is a bundled asset path or inline SVG. */
export function isSafeStyle(style) {
  if (typeof style !== 'string' || style.length > 200_000) return false;
  const match = /(?:^|;)image=([^;]*)/.exec(style);
  if (!match) return false;
  const value = match[1];
  if (EMBEDDED_IMAGE.test(value)) return true;
  return BUILTIN_IMAGE.test(value) && !value.includes('..') && !value.includes('//');
}

/** Drop any entry whose style would point at an external resource. */
function sanitiseIndex(index, source) {
  const icons = index.icons.filter((icon) => isSafeStyle(icon.style));
  const rejected = index.icons.length - icons.length;
  if (icons.length === 0) throw new Error(`Icon index from ${source} contained no entries with a safe style`);
  return { ...index, icons, count: icons.length, rejected, source };
}

/**
 * Load the icon index: live from GitHub so icon updates ship without
 * reinstalls, falling back to the bundled snapshot when offline. Entries with
 * unsafe style strings are dropped before any caller sees them.
 */
export async function loadIndex({ url = process.env.CLOUD_DIAGRAM_ICONS_URL || DEFAULT_INDEX_URL, fetchImpl = fetch } = {}) {
  let fetched;
  try {
    const res = await fetchImpl(url, { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    fetched = await res.json();
    if (!Array.isArray(fetched.icons)) throw new Error('index has no icons array');
  } catch (transportErr) {
    // Only transport and parse failures fall back to the snapshot. A hostile
    // index must never be masked by silently serving the bundled copy.
    for (const candidate of SNAPSHOT_CANDIDATES) {
      let snapshot;
      try {
        snapshot = JSON.parse(await readFile(candidate, 'utf8'));
      } catch {
        continue;
      }
      return sanitiseIndex(snapshot, `${candidate} (offline fallback: ${transportErr.message})`);
    }
    throw new Error(`Could not load icon index from ${url} (${transportErr.message}) or any bundled snapshot`);
  }
  return sanitiseIndex(fetched, url);
}

const norm = (s) => s.toLowerCase().normalize('NFKD');
const tokens = (s) => norm(s).split(/[^a-z0-9]+/).filter(Boolean);

/** True when every query token appears as a whole word in the haystack. */
function wordMatch(queryTokens, haystack) {
  const words = new Set(tokens(haystack));
  return queryTokens.every((t) => words.has(t));
}

/**
 * Rank icons for a query. Word-boundary matching, never raw substring, so
 * "Azure AD" does not match "Azure Advisor". Exact name and alias hits rank
 * first.
 */
export function searchIcons(index, query, { provider, limit = 10 } = {}) {
  const q = norm(query).trim();
  const qTokens = tokens(query);
  if (qTokens.length === 0) return [];

  const scored = [];
  for (const icon of index.icons) {
    if (provider && icon.provider !== provider) continue;
    const aliases = icon.aliases ?? [];
    let score = 0;
    if (norm(icon.name) === q) score = 100;
    else if (aliases.some((a) => norm(a) === q)) score = 90;
    else if (wordMatch(qTokens, icon.name)) score = 70;
    else if (aliases.some((a) => wordMatch(qTokens, a))) score = 60;
    else if (wordMatch(qTokens, `${icon.name} ${aliases.join(' ')} ${icon.tags ?? ''}`)) score = 40;
    if (score > 0) scored.push({ score, icon });
  }

  scored.sort((a, b) => b.score - a.score || a.icon.name.localeCompare(b.icon.name));

  // Two entries with the same style are the same shape, so returning both only
  // asks the caller to choose between identical options. Keep the best-scoring
  // one. Entries that differ in style are kept: some share a name while being
  // genuinely different artwork.
  const seen = new Set();
  const results = [];
  for (const { score, icon } of scored) {
    if (seen.has(icon.style)) continue;
    seen.add(icon.style);
    results.push({ ...publicIcon(icon), score });
    if (results.length >= limit) break;
  }
  return results;
}

/** Exact lookup by name or alias (case-insensitive); falls back to a unique
 * search hit. Returns { icon } or { error, suggestions }. */
export function getIcon(index, name, { provider } = {}) {
  const q = norm(name).trim();
  const pool = provider ? index.icons.filter((i) => i.provider === provider) : index.icons;

  const exact = pool.filter((i) => norm(i.name) === q);
  if (exact.length > 0) return { icon: publicIcon(exact[0]) };

  const byAlias = pool.filter((i) => (i.aliases ?? []).some((a) => norm(a) === q));
  // Matches that all resolve to the same shape are not ambiguous.
  if (byAlias.length > 0 && new Set(byAlias.map((i) => i.style)).size === 1) {
    return { icon: publicIcon(byAlias[0]) };
  }
  if (byAlias.length > 1) return ambiguous(byAlias);

  const hits = searchIcons(index, name, { provider, limit: 6 });
  if (hits.length === 1) return { icon: hits[0] };
  if (hits.length > 1) return ambiguous(hits);
  return { error: `No icon found for "${name}"`, suggestions: [] };
}

function ambiguous(icons) {
  return {
    error: 'Ambiguous name; pick one of the suggestions',
    suggestions: icons.map((i) => i.name),
  };
}

export function listCategories(index, { provider } = {}) {
  const counts = new Map();
  for (const icon of index.icons) {
    if (provider && icon.provider !== provider) continue;
    const key = `${icon.provider}/${icon.category}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return [...counts.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, count]) => {
      const [prov, category] = key.split('/');
      return { provider: prov, category, count };
    });
}

export function listProviders(index) {
  const counts = new Map();
  for (const icon of index.icons) counts.set(icon.provider, (counts.get(icon.provider) ?? 0) + 1);
  return [...counts.entries()].map(([provider, count]) => ({ provider, count }));
}

/** Shape returned to clients: everything needed to place the shape in draw.io. */
function publicIcon(icon) {
  return {
    provider: icon.provider,
    category: icon.category,
    name: icon.name,
    aliases: icon.aliases ?? [],
    w: icon.w,
    h: icon.h,
    ref: icon.ref,
    style: icon.style,
  };
}
