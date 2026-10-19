import type { MailMessage, MailProvider } from './mail-provider.js';

type Fetch = (
  url: string,
  init: { method: string; headers: Record<string, string>; body: string; signal?: AbortSignal },
) => Promise<{ ok: boolean; status: number }>;

export class MailSendError extends Error {
  override readonly name = 'MailSendError';
}

/**
 * Brevo, API transactionnelle (palier gratuit de 300 mails par jour, docs/couts.md). Texte
 * brut seulement ; l'adresse n'apparaît pas dans l'erreur levée (journaux sans données).
 */
export class BrevoMailProvider implements MailProvider {
  constructor(
    private readonly apiKey: string,
    private readonly sender: { email: string; name: string },
    private readonly fetchFn: Fetch = (url, init) => fetch(url, init),
  ) {}

  async send(message: MailMessage): Promise<void> {
    const response = await this.fetchFn('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: { 'api-key': this.apiKey, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({
        sender: this.sender,
        to: [{ email: message.to }],
        subject: message.subject,
        textContent: message.text,
      }),
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new MailSendError(`Brevo HTTP ${response.status}`);
  }
}
