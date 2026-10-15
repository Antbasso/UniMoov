import { describe, expect, it, vi } from 'vitest';
import { createDatabase } from '../../src/db/client.js';

describe('createDatabase', () => {
  it('une erreur de connexion inactive est signalée sans arrêter le processus', async () => {
    const onIdleError = vi.fn();
    const database = createDatabase('postgres://u:p@localhost:1/db', { onIdleError });
    const error = new Error('terminating connection');
    expect(() => database.pool.emit('error', error)).not.toThrow();
    expect(onIdleError).toHaveBeenCalledWith(error);
    await database.close();
  });

  it('sans rappel, l’erreur est quand même absorbée', async () => {
    const database = createDatabase('postgres://u:p@localhost:1/db');
    expect(() => database.pool.emit('error', new Error('x'))).not.toThrow();
    await database.close();
  });
});
