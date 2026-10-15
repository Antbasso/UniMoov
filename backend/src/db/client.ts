import { drizzle, type NodePgDatabase } from 'drizzle-orm/node-postgres';
import pg from 'pg';
import * as schema from './schema.js';

export type Db = NodePgDatabase<typeof schema>;

export interface Database {
  db: Db;
  pool: pg.Pool;
  close: () => Promise<void>;
}

export interface DatabaseOptions {
  /** Erreur d'une connexion inactive (base redémarrée, réseau coupé). */
  onIdleError?: (error: Error) => void;
}

export function createDatabase(url: string, { onIdleError }: DatabaseOptions = {}): Database {
  const pool = new pg.Pool({ connectionString: url, max: 10 });
  // Sans écouteur, une erreur sur une connexion inactive arrêterait le processus ;
  // le pool remplace la connexion fautive à la requête suivante.
  pool.on('error', (error) => onIdleError?.(error));
  const db = drizzle(pool, { schema });
  return { db, pool, close: () => pool.end() };
}
