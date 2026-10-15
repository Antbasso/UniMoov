import type { MailMessage, MailProvider } from './mail-provider.js';

/** Tests : garde les mails envoyés en mémoire. */
export class MemoryMailProvider implements MailProvider {
  readonly sent: MailMessage[] = [];

  send(message: MailMessage): Promise<void> {
    this.sent.push(message);
    return Promise.resolve();
  }

  lastTo(email: string): MailMessage | undefined {
    return this.sent.filter((m) => m.to === email).at(-1);
  }
}
