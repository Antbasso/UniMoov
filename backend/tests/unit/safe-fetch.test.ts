import { describe, expect, it } from 'vitest';
import { SecretBox } from '../../src/shared/crypto.js';
import { fetchPublicText, isPublicAddress, normalizeCalendarUrl, UnsafeUrlError } from '../../src/shared/safe-fetch.js';

describe('isPublicAddress', () => {
  it.each([
    ['93.184.216.34', true],
    ['2606:4700::1111', true],
    ['127.0.0.1', false],
    ['10.1.2.3', false],
    ['172.20.0.5', false],
    ['192.168.1.10', false],
    ['169.254.169.254', false], // métadonnées cloud
    ['100.64.0.1', false],
    ['0.0.0.0', false],
    ['::1', false],
    ['fd00::1', false],
    ['fe80::1', false],
    ['::ffff:127.0.0.1', false],
    ['::ffff:7f00:1', false], // même adresse, écrite en hexadécimal
    ['::ffff:a9fe:a9fe', false], // 169.254.169.254
    ['::7f00:1', false],
    ['64:ff9b::7f00:1', false],
    ['2002:7f00:1::1', false],
    ['2001:0:4136:e378::1', false],
    ['pas-une-ip', false],
  ])('%s → %s', (ip, expected) => {
    expect(isPublicAddress(ip)).toBe(expected);
  });
});

describe('normalizeCalendarUrl', () => {
  it('convertit webcal en https', () => {
    expect(normalizeCalendarUrl('webcal://ade.univ-smb.fr/jsp/custom/modules/plannings/anonymous_cal.jsp?x=1').href).toBe(
      'https://ade.univ-smb.fr/jsp/custom/modules/plannings/anonymous_cal.jsp?x=1',
    );
  });

  it.each([
    'http://ade.univ-smb.fr/cal.ics',
    'https://127.0.0.1/cal.ics',
    'https://[::1]/cal.ics',
    'https://[::ffff:127.0.0.1]/cal.ics', // réécrit en [::ffff:7f00:1] par l'analyseur d'URL
    'https://93.184.216.34/cal.ics', // aucune adresse IP en clair, même publique
    'https://localhost/cal.ics',
    'https://ade.univ-smb.fr:8443/cal.ics',
    'https://user:pass@ade.univ-smb.fr/cal.ics',
    'file:///etc/passwd',
    'pas une url',
  ])('refuse %s', (url) => {
    expect(() => normalizeCalendarUrl(url)).toThrow(UnsafeUrlError);
  });

  it('refuse avant toute connexion une adresse privée', async () => {
    await expect(fetchPublicText('https://169.254.169.254/latest/meta-data')).rejects.toThrow(UnsafeUrlError);
  });
});

describe('SecretBox', () => {
  const key = Buffer.alloc(32, 7).toString('base64');

  it('chiffre puis déchiffre, avec un IV différent à chaque fois', () => {
    const box = new SecretBox(key);
    const a = box.seal('https://ade.univ-smb.fr/cal.ics?token=secret');
    const b = box.seal('https://ade.univ-smb.fr/cal.ics?token=secret');
    expect(a.equals(b)).toBe(false);
    expect(a.toString('utf8')).not.toContain('secret');
    expect(box.open(a)).toBe('https://ade.univ-smb.fr/cal.ics?token=secret');
  });

  it('détecte une altération et refuse une mauvaise clé', () => {
    const box = new SecretBox(key);
    const sealed = box.seal('x');
    sealed[sealed.length - 1]! ^= 1;
    expect(() => box.open(sealed)).toThrow();
    expect(() => new SecretBox(Buffer.alloc(16).toString('base64'))).toThrow();
  });
});
