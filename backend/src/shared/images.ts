/** Type d'une image d'après ses premiers octets (JPEG ou PNG), jamais d'après l'en-tête du client. */
export function imageTypeOf(data: Buffer): 'image/jpeg' | 'image/png' | null {
  if (data.length > 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) return 'image/jpeg';
  if (data.length > 8 && data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  return null;
}

/** Taille maximale d'une photo envoyée (l'app la réduit avant l'envoi). */
export const PHOTO_MAX_BYTES = 600 * 1024;
