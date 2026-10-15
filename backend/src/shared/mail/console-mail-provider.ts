import type { MailMessage, MailProvider } from './mail-provider.js';
import { maskEmail } from './mail-provider.js';

/**
 * Développement uniquement (refusé en production par la config) : écrit le mail dans le
 * journal de l'API pour lire le code sans service externe. L'adresse y est masquée.
 */
export class ConsoleMailProvider implements MailProvider {
  constructor(private readonly log: (line: string) => void) {}

  send(message: MailMessage): Promise<void> {
    this.log(`[mail de développement] à ${maskEmail(message.to)} : ${message.subject}\n${message.text}`);
    return Promise.resolve();
  }
}
