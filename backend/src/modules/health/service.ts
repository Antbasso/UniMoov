import type { HealthResponse } from './schema.js';

export type PingDb = () => Promise<void>;

export async function checkHealth(pingDb: PingDb): Promise<HealthResponse> {
  try {
    await pingDb();
    return { status: 'ok', db: 'ok' };
  } catch {
    return { status: 'degraded', db: 'down' };
  }
}
