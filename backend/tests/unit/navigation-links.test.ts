import { describe, expect, it } from 'vitest';
import {
  appleMapsLink,
  googleMapsLink,
  navigationLinks,
  SUPPORTS_MULTI_STOP,
  wazeLink,
} from '../../src/modules/navigation/links.js';

const hugo = { lat: 45.905, lon: 6.103 };
const ines = { lat: 45.8992, lon: 6.1294 };
const campus = { lat: 45.9195, lon: 6.158 };

describe('googleMapsLink', () => {
  it('contient tous les arrêts dans l’ordre, puis la destination', () => {
    const url = new URL(googleMapsLink([hugo, ines, campus]));
    expect(url.origin + url.pathname).toBe('https://www.google.com/maps/dir/');
    expect(url.searchParams.get('api')).toBe('1');
    expect(url.searchParams.get('waypoints')).toBe('45.905000,6.103000|45.899200,6.129400');
    expect(url.searchParams.get('destination')).toBe('45.919500,6.158000');
    expect(url.searchParams.get('travelmode')).toBe('driving');
    // Pas d'origine : départ de la position actuelle.
    expect(url.searchParams.has('origin')).toBe(false);
  });

  it('l’ordre des étapes est conservé tel quel', () => {
    const reversed = new URL(googleMapsLink([ines, hugo, campus])).searchParams.get('waypoints');
    expect(reversed).toBe('45.899200,6.129400|45.905000,6.103000');
  });

  it('sans arrêt restant : destination seule, sans étapes', () => {
    const url = new URL(googleMapsLink([campus]));
    expect(url.searchParams.has('waypoints')).toBe(false);
    expect(url.searchParams.get('destination')).toBe('45.919500,6.158000');
  });
});

describe('appleMapsLink', () => {
  it('enchaîne les destinations avec « to: », en voiture', () => {
    expect(appleMapsLink([hugo, ines, campus])).toBe(
      'https://maps.apple.com/?daddr=45.905000,6.103000+to:45.899200,6.129400+to:45.919500,6.158000&dirflg=d',
    );
  });
});

describe('wazeLink', () => {
  it('une seule destination, navigation lancée', () => {
    expect(wazeLink(hugo)).toBe('https://waze.com/ul?ll=45.905000,6.103000&navigate=yes');
    expect(SUPPORTS_MULTI_STOP.waze).toBe(false);
  });
});

describe('navigationLinks', () => {
  it('Waze pointe vers l’arrêt suivant, les autres vers tout le trajet', () => {
    const links = navigationLinks([hugo, ines, campus]);
    expect(links.waze.nextStop).toBe(wazeLink(hugo));
    expect(links.googleMaps).toBe(googleMapsLink([hugo, ines, campus]));
  });

  it('jamais de donnée personnelle : seulement des coordonnées et des paramètres connus', () => {
    const all = Object.values(navigationLinks([hugo, campus])).flatMap((v) => (typeof v === 'string' ? [v] : Object.values(v)));
    for (const link of all) expect(decodeURIComponent(link)).toMatch(/^https:\/\/[a-z.]+\/[a-z/]*\?[a-z0-9=,.&|+:_-]+$/i);
  });

  it('refuse une liste vide ou des coordonnées invalides', () => {
    expect(() => googleMapsLink([])).toThrow(RangeError);
    expect(() => wazeLink({ lat: 95, lon: 0 })).toThrow(RangeError);
    expect(() => appleMapsLink([{ lat: Number.NaN, lon: 1 }])).toThrow(RangeError);
  });
});
