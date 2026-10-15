Bouton d'action d'Uni-Moov : trois variantes, rayon `radius-md`, 48 px de haut minimum.

- `primary` : fond `brand`, texte `on-brand`. Une seule par écran, pour l'action principale (« Proposer un trajet »).
- `secondary` : fond `surface-raised`, bordure `border-control`, texte `brand-strong`. Action alternative.
- `ghost` : sans fond, texte `brand-strong`. Annuler, retour, actions tertiaires.
- `pill` ajoute `radius-pill` pour les appels à l'action de héros ou d'affiche.

Le consommateur fournit le libellé (verbe à l'infinitif ou à l'impératif, tutoiement) et l'icône éventuelle (trait de 2,5 px, `currentColor`). Le focus clavier utilise toujours l'anneau `focus` de 3 px. Un bouton désactivé reste lisible et ne porte jamais seul un message d'erreur.

À éviter : deux boutons `primary` côte à côte, un texte blanc sur `brand-top` ou `brand-bottom`, des libellés en capitales.
