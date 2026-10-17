import { describe, expect, it } from 'vitest';
import { BrevoMailProvider, MailSendError } from '../../src/shared/mail/brevo-mail-provider.js';

describe('BrevoMailProvider', () => {
  const sender = { email: 'unimoov.support@gmail.com', name: 'Uni-Moov' };

  it('envoie le texte brut avec la clé dans l’en-tête', async () => {
    const calls: { url: string; headers: Record<string, string>; body: string }[] = [];
    const provider = new BrevoMailProvider('cle-brevo', sender, (url, init) => {
      calls.push({ url, headers: init.headers, body: init.body });
      return Promise.resolve({ ok: true, status: 201 });
    });
    await provider.send({ to: 'lea.martin@etu.univ-smb.fr', subject: '123456 est ton code', text: 'Bonjour' });
    expect(calls[0]!.url).toBe('https://api.brevo.com/v3/smtp/email');
    expect(calls[0]!.headers['api-key']).toBe('cle-brevo');
    expect(JSON.parse(calls[0]!.body)).toEqual({
      sender,
      to: [{ email: 'lea.martin@etu.univ-smb.fr' }],
      subject: '123456 est ton code',
      textContent: 'Bonjour',
    });
  });

  it('refus du service : erreur sans l’adresse du destinataire', async () => {
    const provider = new BrevoMailProvider('cle', sender, () => Promise.resolve({ ok: false, status: 401 }));
    const error = await provider.send({ to: 'lea.martin@etu.univ-smb.fr', subject: 's', text: 't' }).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(MailSendError);
    expect((error as Error).message).not.toContain('lea.martin');
  });
});
