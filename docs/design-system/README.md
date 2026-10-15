Uni-Moov est une application de covoiturage étudiant. Sa marque est ronde, violette et amicale : une tache organique, une voiture blanche, un mot-symbole manuscrit. Ce système est construit à partir du logo et de l'affiche de sondage « Ton avis compte ! ». Les composants d'écran (RideCard) sont des ajouts déduits de ces sources.

## Fondamentaux du contenu

- Tutoiement systématique, ton direct et encourageant : « Ton avis compte ! », « Aide-nous à développer Uni-Moov », « Scanne le QR code et réponds en quelques minutes ! ».
- Phrases courtes, verbes à l'impératif pour les actions, bénéfice chiffré ou concret (« 5 minutes seulement »). Une seule exclamation par écran, pas d'emoji.
- Casse de phrase partout : majuscule initiale seulement. Le nom s'écrit « Uni-Moov », avec trait d'union et deux M majuscules.
- Remercier en fin de parcours (« Merci pour ta participation ! »).

## Fondations visuelles

- **Couleur.** Une seule teinte, le violet. Fond `surface`, texte `ink` (marine très sombre), accents `brand` pour les aplats d'action et `brand-strong` pour sous-titres, liens et icônes. Les aplats doux utilisent `lavender` et `surface-tint`. Le dégradé de la tache du logo va de `brand-top` à `brand-bottom` : il n'existe que dans le logo et dans les collines de pied d'affiche, jamais comme fond de bouton ou de carte. Le noir pur n'apparaît que dans « Moov » du logo.
- **Texte sur violet.** `on-brand` sur `brand` uniquement. Jamais de texte sur `brand-top` ou `brand-bottom`.
- **Typographie.** UniMoov Display (`display`, fichier `fonts/UniMoovDisplay-SemiBold.woff2`) pour tous les titres (`display`, `h1`, `h2`, `h3`) et pour les prix : c'est la voix typographique de la marque, reconnaissable à ses points légèrement organiques, comme la tache du logo (i, j, !, ?, :, ;). Poppins (`sans`) en 400 à 600 pour le texte (`body`, `body-sm`, `label`, `caption`). N'emploie jamais UniMoov Display pour du texte courant ou sous 18 px, ni en capitales, et ne la simule pas en gras (une seule graisse, 600). Caveat (`hand`, style `note`) pour une annotation manuscrite par écran ou affiche, en `brand-strong` sur `lavender`, 24 px minimum. Poppins et Caveat sont chargées depuis Google Fonts ; UniMoov Display est un fichier du système. Le mot-symbole du logo reste toujours l'image fournie : la police n'est pas le logo. UniMoov Display dérive de Fredoka (licence SIL OFL 1.1, redistribuable et modifiable) et ne couvre que l'alphabet latin, accents français compris.
- **Formes et rayons.** Tout est arrondi : `radius-sm` (champs), `radius-md` (boutons, cartes de trajet), `radius-lg` (grandes cartes, cadre QR), `radius-pill` (puces). Le motif de marque est la tache organique et le disque.
- **Espacement.** Échelle `space-1` (4) à `space-8` (64). Marges d'écran `space-6`, padding de carte `space-4` à `space-5`.
- **Ombres.** Une seule, `shadow-soft` : lueur violette diffuse en thème clair.
- **Arrière-plans.** Fond clair et aéré, une grande tache violette en coin et des collines violettes superposées en pied (dos en `brand-top`, plan avant en `brand-strong`). Pas de photo ni de texture.
- **Focus et contrastes.** Anneau `focus` de 3 px plein, jamais supprimé. Bordures de contrôle en `border-control` (3:1). Les statuts portent un mot et une icône, jamais la couleur seule. Chaque paire de texte tient 4.5:1 en thème clair et sombre.
- **Mouvement.** Transitions de 150 ms sur fond et bordure seulement.

## Iconographie

- Icônes au trait, 48 px sur l'affiche, 24 px en interface, trait de 2,5 px (2 px en 16 px), bouts et angles arrondis, sans remplissage, en `brand-strong`. Pictos de référence : voiture, horloge, ampoule, personnes, épingle de lieu avec trajet pointillé.
- La voiture pleine blanche n'existe que dans le logo. Pas d'emoji ni de pictogrammes décoratifs.

## Logo et images

- Utilise le logo complet `assets/logo.png` sur fond clair, et l'icône seule (`uni-moov-icon.png`, fond transparent, **pas encore fournie dans le dépôt**) quand la place manque. Ne redessine, ne recolore et ne déforme jamais ces fichiers ; règles détaillées dans `logo.md`.
- L'affiche de sondage (non versionnée dans le dépôt) montre la composition type d'une affiche : logo en tête, titre `display`, sous-titre `h2` en `brand-strong`, carte QR en cadre `lavender` avec sticker manuscrit, trois bénéfices `Benefit`, collines en pied.

## Composants

`Button` (principal, secondaire, discret), `Chip` (puces et sticker `note`), `Field` (saisie), `Card` (carte flottante et cadre QR), `Benefit` (icône + légende), `RideCard` (trajet). Chaque composant utilise uniquement les tokens ; les classes `um-*` vivent dans `components.css`.
