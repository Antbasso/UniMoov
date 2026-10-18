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
  bool _busy = false;
  String? _errorCode;
  bool _yearInvalid = false;

  Me? get _me => ref.read(meProvider).value;

  @override
  void dispose() {
    _study.dispose();
    _year.dispose();
    _interest.dispose();
    super.dispose();
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
        Text(l10n.aboutInterests, style: UmText.label.copyWith(color: c.ink)),
        const SizedBox(height: UmSpace.s2),
        if (_interests.isNotEmpty)
          Wrap(
            spacing: UmSpace.s2,
            runSpacing: UmSpace.s2,
            children: [
              for (final interest in _interests)
                InputChip(
                  label: Text(interest),
                  deleteButtonTooltipMessage: l10n.aboutInterestRemove(interest),
                  onDeleted: () => setState(() => _interests.remove(interest)),
                ),
            ],
          ),
        const SizedBox(height: UmSpace.s2),
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
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}
