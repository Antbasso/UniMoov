import type { MailMessage } from '../../shared/mail/mail-provider.js';
import { AUTH_POLICY } from './policy.js';

/** Mails de l'inscription (tutoiement, phrases courtes, « Uni-Moov »). */
export function signupCodeMail(to: string, code: string): MailMessage {
  return {
    to,
    subject: `Ton code Uni-Moov : ${code}`,
    text: [
      `Voici ton code de confirmation : ${code}`,
      `Il est valable ${AUTH_POLICY.codeTtlMinutes} minutes et ne sert qu'une fois.`,
      "Si tu n'as rien demandé, ignore ce mail.",
    ].join('\n\n'),
  };
}

export function accountExistsMail(to: string): MailMessage {
  return {
    to,
    subject: 'Tu as déjà un compte Uni-Moov',
    text: [
      'Quelqu’un a demandé à créer un compte avec ton adresse, mais tu en as déjà un.',
      'Connecte-toi avec ton mot de passe. Si ce n’était pas toi, ignore ce mail.',
    ].join('\n\n'),
  };
}
