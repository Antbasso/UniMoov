/**
 * Crée une migration SQL vide et l'inscrit au journal Drizzle.
 * Usage : npm run db:new-migration -- add_something
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { migrationsFolder } from '../src/db/migrate.js';

interface JournalEntry {
  idx: number;
  version: string;
  when: number;
  tag: string;
  breakpoints: boolean;
}

const name = process.argv[2];
if (!name || !/^[a-z0-9_]+$/.test(name)) {
  console.error('Nom attendu en snake_case, ex. : npm run db:new-migration -- add_wallet_index');
  process.exit(1);
}

const journalPath = join(migrationsFolder, 'meta', '_journal.json');
const journal = JSON.parse(readFileSync(journalPath, 'utf8')) as { entries: JournalEntry[] };
const last = journal.entries.at(-1);
const idx = last ? last.idx + 1 : 0;
const tag = `${String(idx).padStart(4, '0')}_${name}`;

journal.entries.push({ idx, version: '7', when: Date.now(), tag, breakpoints: true });
writeFileSync(join(migrationsFolder, `${tag}.sql`), `-- ${name}\n`);
writeFileSync(journalPath, `${JSON.stringify(journal, null, 2)}\n`);
console.log(`migrations/${tag}.sql créé`);
