import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/ride.dart';
import 'rides_controller.dart';

/// Conducteur : passagers supplémentaires, y compris au-delà de son détour, avec la baisse
/// de prix simulée (cahier §4). Inviter envoie une proposition que la personne accepte.
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  String? _busyId;
  String? _errorCode;

  Future<void> _invite(Suggestion s) async {
    setState(() {
      _busyId = s.person.userId;
      _errorCode = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(suggestionsProvider(widget.id).notifier).invite(s.person.userId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.suggestionInvited(s.person.firstName))));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final suggestions = ref.watch(suggestionsProvider(widget.id));
    String euros(int cents) => UmRideCard.formatPrice(cents, l10n.localeName);

    return UmPage(
      appBar: AppBar(),
      title: l10n.suggestionsTitle,
      intro: l10n.suggestionsIntro,
      children: switch (suggestions) {
        AsyncData(:final value) => [
          if (value.currentPassengerPaysCents != null) ...[
            Text(
              l10n.suggestionsCurrentPrice(euros(value.currentPassengerPaysCents!)),
              style: UmText.body.copyWith(color: c.ink),
            ),
            const SizedBox(height: UmSpace.s4),
          ],
          if (_errorCode != null) ...[
            UmErrorText(apiErrorMessage(l10n, _errorCode)),
            const SizedBox(height: UmSpace.s4),
          ],
          if (value.seatsLeft <= 0)
            Text(l10n.suggestionsFull, style: UmText.body.copyWith(color: c.inkMuted))
          else if (value.items.isEmpty)
            Text(l10n.suggestionsEmpty, style: UmText.body.copyWith(color: c.inkMuted))
          else
            for (final s in value.items)
              Padding(
                padding: const EdgeInsets.only(bottom: UmSpace.s3),
                child: UmCard(
                  title: s.person.firstName,
                  body: l10n.personDetails(s.person.scoreOutOfFive, s.person.detourMinutes),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      s.withinDetourLimit
                          ? UmChip(
                              label: l10n.suggestionWithin,
                              icon: Icons.check_circle_outline_rounded,
                              tone: UmChipTone.success,
                            )
                          : UmChip(label: l10n.suggestionBeyond, icon: Icons.alt_route_rounded),
                      const SizedBox(height: UmSpace.s3),
                      Text(
                        l10n.suggestionPrice(euros(s.passengerPaysCents)),
                        style: UmText.body.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: UmSpace.s3),
                      UmButton(
                        label: l10n.suggestionInvite,
                        variant: UmButtonVariant.secondary,
                        loading: _busyId == s.person.userId,
                        onPressed: _busyId == null ? () => _invite(s) : null,
                      ),
                    ],
                  ),
                ),
              ),
        ],
        AsyncError(:final error) => [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(suggestionsProvider(widget.id)),
          ),
        ],
        _ => [
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        ],
      },
    );
  }
}
