import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/clock.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/me.dart';
import 'me_controller.dart';
import 'profile_labels.dart';

/// Nombre de centres d'intérêt au plus (comme le serveur).
const maxInterests = 6;

/// « À propos de moi » : formation, année de naissance (seul l'âge est montré) et centres
/// d'intérêt, visibles par les étudiants croisés sur un trajet. Tout est facultatif.
class EditAboutScreen extends ConsumerStatefulWidget {
  const EditAboutScreen({super.key});

  @override
  ConsumerState<EditAboutScreen> createState() => _EditAboutScreenState();
}

class _EditAboutScreenState extends ConsumerState<EditAboutScreen> {
  late final _study = TextEditingController(text: _me?.studyProgram ?? '');
  late final _year = TextEditingController(text: _me?.birthYear?.toString() ?? '');
  final _interest = TextEditingController();
  late final List<String> _interests = [...?_me?.interests];
  late final _bio = TextEditingController(text: _me?.bio ?? '');
  late CarpoolPreferences _prefs = _me?.preferences ?? const CarpoolPreferences();
  bool _busy = false;
  String? _errorCode;
  bool _yearInvalid = false;

  Me? get _me => ref.read(meProvider).value;

  @override
  void dispose() {
    _study.dispose();
    _year.dispose();
    _interest.dispose();
    _bio.dispose();
    super.dispose();
  }

  /// Centre d'intérêt proposé : le toucher l'ajoute, le retoucher le retire.
  void _toggle(String interest) {
    setState(() {
      final known = _interests.where((i) => i.toLowerCase() == interest.toLowerCase());
      if (known.isNotEmpty) {
        _interests.remove(known.first);
      } else if (_interests.length < maxInterests) {
        _interests.add(interest);
      }
    });
  }

  void _addInterest() {
    final text = _interest.text.trim();
    if (text.isEmpty || _interests.length >= maxInterests) return;
    if (_interests.any((i) => i.toLowerCase() == text.toLowerCase())) return;
    setState(() {
      _interests.add(text.length > 30 ? text.substring(0, 30) : text);
      _interest.clear();
    });
  }

  Future<void> _save() async {
    final now = ref.read(clockProvider)();
    final year = int.tryParse(_year.text.trim());
    final invalid =
        _year.text.trim().isNotEmpty && (year == null || year < 1940 || year > now.year - 15);
    setState(() {
      _yearInvalid = invalid;
      _errorCode = null;
    });
    if (invalid) return;
    _addInterest();
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(meProvider.notifier)
          .updateAbout(
            studyProgram: _study.text.trim().isEmpty ? null : _study.text.trim(),
            birthYear: year,
            interests: _interests,
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            preferences: _prefs,
          );
      if (router.canPop()) router.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final full = _interests.length >= maxInterests;
    return UmPage(
      appBar: AppBar(),
      title: l10n.aboutTitle,
      intro: l10n.aboutIntro,
      footer: [UmButton(label: l10n.save, expand: true, loading: _busy, onPressed: _save)],
      children: [
        UmField(
          label: l10n.aboutStudy,
          placeholder: l10n.aboutStudyHint,
          controller: _study,
          maxLength: 80,
        ),
        const SizedBox(height: UmSpace.s4),
        UmField(
          label: l10n.aboutBirthYear,
          help: l10n.aboutBirthYearHelp,
          placeholder: '2005',
          controller: _year,
          keyboardType: TextInputType.number,
          error: _yearInvalid ? l10n.aboutBirthYearInvalid : null,
        ),
        const SizedBox(height: UmSpace.s4),
        UmField(
          label: l10n.aboutBio,
          placeholder: l10n.aboutBioHint,
          controller: _bio,
          maxLines: 3,
          maxLength: 200,
        ),
        const SizedBox(height: UmSpace.s5),
        UmSectionTitle(l10n.aboutInterests),
        const SizedBox(height: UmSpace.s1),
        Text(
          l10n.aboutInterestsHelp(_interests.length, maxInterests),
          style: UmText.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: UmSpace.s3),
        // Choix tout prêts, par thème et couleur ; ses propres mots restent possibles dessous.
        InterestPicker(selected: _interests, full: full, onToggle: _toggle),
        const SizedBox(height: UmSpace.s3),
        if (!full)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: UmField(
                  label: l10n.aboutInterestAdd,
                  placeholder: l10n.aboutInterestHint,
                  controller: _interest,
                  maxLength: 30,
                ),
              ),
              IconButton(
                tooltip: l10n.aboutInterestAdd,
                icon: Icon(Icons.add_circle_outline_rounded, color: c.brandStrong),
                onPressed: _addInterest,
              ),
            ],
          ),
        const SizedBox(height: UmSpace.s5),
        UmSectionTitle(l10n.prefsTitle),
        const SizedBox(height: UmSpace.s2),
        PreferencePicker(
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.prefChatTitle,
          values: CarpoolPreferences.chatValues,
          selected: _prefs.chat,
          labelOf: (v) => preferenceLabel(l10n, 'chat', v),
          onChanged: (v) => setState(() => _prefs = _prefs.copyWith(chat: () => v)),
        ),
        PreferencePicker(
          icon: Icons.music_note_outlined,
          title: l10n.prefMusicTitle,
          values: CarpoolPreferences.musicValues,
          selected: _prefs.music,
          labelOf: (v) => preferenceLabel(l10n, 'music', v),
          onChanged: (v) => setState(() => _prefs = _prefs.copyWith(music: () => v)),
        ),
        PreferencePicker(
          icon: Icons.smoke_free_rounded,
          title: l10n.prefSmokingTitle,
          values: CarpoolPreferences.smokingValues,
          selected: _prefs.smoking,
          labelOf: (v) => preferenceLabel(l10n, 'smoking', v),
          onChanged: (v) => setState(() => _prefs = _prefs.copyWith(smoking: () => v)),
        ),
        PreferencePicker(
          icon: Icons.pets_outlined,
          title: l10n.prefPetsTitle,
          values: CarpoolPreferences.petsValues,
          selected: _prefs.pets,
          labelOf: (v) => preferenceLabel(l10n, 'pets', v),
          onChanged: (v) => setState(() => _prefs = _prefs.copyWith(pets: () => v)),
        ),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}
