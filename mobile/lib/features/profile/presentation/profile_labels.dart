import 'package:flutter/material.dart';

import '../../../core/theme/um_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Thème d'un centre d'intérêt : donne sa couleur une fois choisi (le texte dit le reste).
enum InterestTheme { sport, culture, outing }

/// Centres d'intérêt proposés (6 au plus par profil), par thème ; écrits tels quels.
const interestCatalog = <InterestTheme, List<String>>{
  InterestTheme.sport: [
    'Randonnée',
    'Ski',
    'Escalade',
    'Vélo',
    'Course à pied',
    'Football',
    'Natation',
    'Yoga',
    'Montagne',
    'Lac',
  ],
  InterestTheme.culture: [
    'Musique',
    'Concerts',
    'Cinéma',
    'Séries',
    'Lecture',
    'Photographie',
    'Dessin',
    'Théâtre',
    'Jeux vidéo',
    'Langues',
    'Sciences',
    'Tech',
  ],
  InterestTheme.outing: [
    'Cuisine',
    'Pâtisserie',
    'Brunch',
    'Café',
    'Jeux de société',
    'Voyage',
    'Danse',
    'Bénévolat',
    'Écologie',
    'Animaux',
    'Podcasts',
    'Soirées',
  ],
};

InterestTheme? interestThemeOf(String interest) {
  final lower = interest.toLowerCase();
  for (final MapEntry(:key, :value) in interestCatalog.entries) {
    if (value.any((i) => i.toLowerCase() == lower)) return key;
  }
  return null;
}

/// Couleur d'un centre d'intérêt choisi (centre propre à la personne : violet de la marque).
Color interestColor(UmColorTokens c, String interest) => switch (interestThemeOf(interest)) {
  InterestTheme.sport => c.success,
  InterestTheme.outing => c.danger,
  InterestTheme.culture || null => c.brandStrong,
};

/// Pastille d'un centre d'intérêt : contour de sa couleur (texte en encre, lisible partout), coche
/// si choisi.
class InterestChip extends StatelessWidget {
  const InterestChip({super.key, required this.label, this.selected = true, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final color = selected ? interestColor(c, label) : c.inkMuted;
    final chip = Container(
      constraints: onTap == null ? null : const BoxConstraints(minHeight: UmSize.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: UmSpace.s3, vertical: UmSpace.s1),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(UmRadius.pill),
        border: Border.all(color: selected ? color : c.border, width: selected ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected && onTap != null) ...[
            Icon(Icons.check_rounded, size: UmSize.iconSm, color: color),
            const SizedBox(width: UmSpace.s1),
          ],
          Flexible(
            child: Text(label, style: UmText.label.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
    if (onTap == null) return Semantics(label: label, excludeSemantics: true, child: chip);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(borderRadius: BorderRadius.circular(UmRadius.pill), onTap: onTap, child: chip),
    );
  }
}

/// Choix des centres d'intérêt : ceux déjà choisis (y compris les siens) puis les propositions.
class InterestPicker extends StatelessWidget {
  const InterestPicker({
    super.key,
    required this.selected,
    required this.full,
    required this.onToggle,
  });

  final List<String> selected;
  final bool full;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    bool isSelected(String i) => selected.any((s) => s.toLowerCase() == i.toLowerCase());
    final own = selected.where((s) => interestThemeOf(s) == null);
    return Wrap(
      spacing: UmSpace.s2,
      runSpacing: UmSpace.s2,
      children: [
        for (final interest in own) InterestChip(label: interest, onTap: () => onToggle(interest)),
        for (final list in interestCatalog.values)
          for (final interest in list)
            InterestChip(
              label: interest,
              selected: isSelected(interest),
              // Six choisis : les autres ne s'ajoutent plus, mais se retirent toujours.
              onTap: full && !isSelected(interest) ? null : () => onToggle(interest),
            ),
      ],
    );
  }
}

/// Libellé d'une préférence de covoiturage (« J'aime discuter »).
String preferenceLabel(AppLocalizations l10n, String kind, String value) => switch ((kind, value)) {
  ('chat', 'chatty') => l10n.prefChatChatty,
  ('chat', 'depends') => l10n.prefChatDepends,
  ('chat', 'quiet') => l10n.prefChatQuiet,
  ('music', 'yes') => l10n.prefMusicYes,
  ('music', 'depends') => l10n.prefMusicDepends,
  ('music', 'no') => l10n.prefMusicNo,
  ('smoking', 'ok') => l10n.prefSmokingOk,
  ('smoking', 'outside') => l10n.prefSmokingOutside,
  ('smoking', 'no') => l10n.prefSmokingNo,
  ('pets', 'yes') => l10n.prefPetsYes,
  ('pets', 'some') => l10n.prefPetsSome,
  ('pets', 'no') => l10n.prefPetsNo,
  _ => value,
};

/// Icône d'une préférence : barrée quand c'est « non ».
IconData preferenceIcon(String kind, String value) => switch ((kind, value)) {
  ('chat', 'quiet') => Icons.speaker_notes_off_outlined,
  ('chat', _) => Icons.chat_bubble_outline_rounded,
  ('music', 'no') => Icons.music_off_outlined,
  ('music', _) => Icons.music_note_outlined,
  ('smoking', 'ok') => Icons.smoking_rooms_outlined,
  ('smoking', _) => Icons.smoke_free_rounded,
  ('pets', 'no') => Icons.do_not_touch_outlined,
  ('pets', _) => Icons.pets_outlined,
  _ => Icons.tune_rounded,
};

/// Une préférence : son titre et ses choix ; retoucher le choix actif l'efface.
class PreferencePicker extends StatelessWidget {
  const PreferencePicker({
    super.key,
    required this.icon,
    required this.title,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final List<String> values;
  final String? selected;
  final String Function(String) labelOf;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: UmSize.iconMd, color: c.brandStrong),
              const SizedBox(width: UmSpace.s2),
              Expanded(
                child: Text(title, style: UmText.label.copyWith(color: c.ink)),
              ),
            ],
          ),
          const SizedBox(height: UmSpace.s2),
          Wrap(
            spacing: UmSpace.s2,
            runSpacing: UmSpace.s2,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(labelOf(v)),
                  selected: selected == v,
                  onSelected: (_) => onChanged(selected == v ? null : v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
