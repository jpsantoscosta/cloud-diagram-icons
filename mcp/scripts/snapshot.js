// Copies the repo's icons.json into the package as the offline fallback
// snapshot. Runs automatically at pack/publish time (prepack).
import { mkdirSync, cpSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const pkgRoot = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
mkdirSync(path.join(pkgRoot, 'data'), { recursive: true });
cpSync(path.join(pkgRoot, '..', 'icons.json'), path.join(pkgRoot, 'data', 'icons.json'));
console.log('snapshotted icons.json into data/');
