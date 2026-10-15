/** Envoi de mails transactionnels, derrière une interface pour changer de fournisseur. */
export interface MailMessage {
  to: string;
  subject: string;
  text: string;
}

export interface MailProvider {
  send(message: MailMessage): Promise<void>;
}

/** Masque une adresse pour les journaux : `l***@etu.univ-smb.fr`. */
export function maskEmail(email: string): string {
  const [local = '', domain = ''] = email.split('@');
  return `${local.slice(0, 1)}***@${domain}`;
}
