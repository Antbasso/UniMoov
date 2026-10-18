import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/me.dart';
import '../domain/vehicle_input.dart';
import 'address_suggestions.dart';
import 'me_controller.dart';

/// Habillage commun : étape d'onboarding (avec « Passer ») ou modification depuis le profil.
class ProfileFormFrame {
  const ProfileFormFrame({
    required this.primaryLabel,
    required this.onDone,
    this.onSkip,
    this.overline,
    this.appBar,
  });

  final String primaryLabel;
  final Future<void> Function() onDone;
  final Future<void> Function()? onSkip;
  final String? overline;
  final PreferredSizeWidget? appBar;
}

/// Exécute une action avec indicateur et message d’erreur traduit (formulaires de profil).
mixin SubmitStateMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  String? errorCode;

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      errorCode = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => errorCode = error.code);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Widget> footerFor(ProfileFormFrame frame, AppLocalizations l10n, VoidCallback submit) => [
    UmButton(label: frame.primaryLabel, expand: true, loading: busy, onPressed: submit),
    if (frame.onSkip != null)
      UmButton(
        label: l10n.skipForNow,
        variant: UmButtonVariant.ghost,
        expand: true,
        onPressed: busy ? null : () => run(frame.onSkip!),
      ),
  ];

  List<Widget> errorFor(AppLocalizations l10n) => [
    if (errorCode != null) ...[
      const SizedBox(height: UmSpace.s4),
      UmErrorText(apiErrorMessage(l10n, errorCode)),
    ],
  ];
}

class AddressForm extends ConsumerStatefulWidget {
  const AddressForm({super.key, required this.me, required this.frame});

  final Me me;
  final ProfileFormFrame frame;

  @override
  ConsumerState<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<AddressForm> with SubmitStateMixin {
  late final _address = TextEditingController(text: widget.me.home?.address ?? '');
  bool _showFieldErrors = false;

  /// Adresse choisie dans les propositions (elle existe vraiment), ou l'adresse actuelle.
  late String? _selected = widget.me.home?.address;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    if (text.trim() != _selected) setState(() => _selected = null);
    ref.read(addressSuggestionsProvider.notifier).search(text);
  }

  void _choose(String label) {
    _address.text = label;
    setState(() => _selected = label);
    ref.read(addressSuggestionsProvider.notifier).clear();
    FocusScope.of(context).unfocus();
  }

  void _submit() {
    setState(() => _showFieldErrors = true);
    final text = _address.text.trim();
    // Seule une adresse proposée (donc existante) est acceptée.
    if (text.length < 5 || _selected != text) return;
    run(() async {
      // Adresse inchangée : rien à géocoder.
      if (text != widget.me.home?.address) {
        await ref.read(meProvider.notifier).setAddress(text);
      }
      await widget.frame.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = widget.me.home;
    return UmPage(
      appBar: widget.frame.appBar,
      overline: widget.frame.overline,
      title: l10n.addressTitle,
      intro: l10n.addressBody,
      footer: footerFor(widget.frame, l10n, _submit),
      children: [
        UmField(
          label: l10n.addressLabel,
          controller: _address,
          placeholder: l10n.addressPlaceholder,
          keyboardType: TextInputType.streetAddress,
          autofillHints: const [AutofillHints.fullStreetAddress],
          onChanged: _onChanged,
          help: l10n.addressPickHelp,
          error: !_showFieldErrors
              ? null
              : _address.text.trim().length < 5
              ? l10n.fieldRequired
              : _selected != _address.text.trim()
              ? l10n.addressPickRequired
              : null,
        ),
        _Suggestions(onChoose: _choose),
        if (home != null) ...[
          const SizedBox(height: UmSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: UmChip(
              label: l10n.addressFound(home.address),
              icon: Icons.check_circle_outline_rounded,
              tone: UmChipTone.success,
            ),
          ),
        ],
        ...errorFor(l10n),
      ],
    );
  }
}

/// Propositions sous le champ : chargement, aucune adresse, erreur, liste à toucher.
class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.onChoose});

  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final state = ref.watch(addressSuggestionsProvider);
    if (state == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: UmSpace.s2),
      child: switch (state) {
        AsyncData(:final value) when value.isEmpty => Text(
          l10n.addressNoSuggestion,
          style: UmText.bodySm.copyWith(color: c.inkMuted),
        ),
        AsyncData(:final value) => Material(
          color: c.surfaceRaised,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UmRadius.md),
            side: BorderSide(color: c.border),
          ),
          child: Column(
            children: [
              for (final label in value)
                ListTile(
                  minTileHeight: UmSize.tapTarget,
                  leading: Icon(Icons.place_outlined, color: c.brandStrong),
                  title: Text(label, style: UmText.body.copyWith(color: c.ink)),
                  onTap: () => onChoose(label),
                ),
            ],
          ),
        ),
        AsyncError(:final error) => UmErrorText(
          apiErrorMessage(l10n, error is ApiException ? error.code : null),
        ),
        _ => Semantics(
          label: l10n.loading,
          child: LinearProgressIndicator(color: c.brand),
        ),
      },
    );
  }
}

class VehicleForm extends ConsumerStatefulWidget {
  const VehicleForm({super.key, required this.me, required this.frame});

  final Me me;
  final ProfileFormFrame frame;

  @override
  ConsumerState<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends ConsumerState<VehicleForm> with SubmitStateMixin {
  late bool _hasCar = widget.me.vehicle != null;
  late final _consumption = TextEditingController(
    text: VehicleInput.formatConsumption(widget.me.vehicle?.consumptionLPer100km ?? 6),
  );
  late final _seats = TextEditingController(text: '${widget.me.vehicle?.defaultSeats ?? 3}');
  late final _detour = TextEditingController(text: '${widget.me.vehicle?.maxDetourMinutes ?? 10}');
  bool _showFieldErrors = false;

  @override
  void dispose() {
    for (final c in [_consumption, _seats, _detour]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    setState(() => _showFieldErrors = true);
    final controller = ref.read(meProvider.notifier);
    if (!_hasCar) {
      run(() async {
        if (widget.me.vehicle != null) await controller.removeVehicle();
        await widget.frame.onDone();
      });
      return;
    }
    final consumption = VehicleInput.consumption(_consumption.text);
    final seats = VehicleInput.seats(_seats.text);
    final detour = VehicleInput.detour(_detour.text);
    if (consumption == null || seats == null || detour == null) return;
    run(() async {
      await controller.setVehicle(
        Vehicle(consumptionLPer100km: consumption, defaultSeats: seats, maxDetourMinutes: detour),
      );
      await widget.frame.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? check(Object? parsed, num min, num max) =>
        _showFieldErrors && parsed == null ? l10n.fieldNumberInvalid(min, max) : null;

    return UmPage(
      appBar: widget.frame.appBar,
      overline: widget.frame.overline,
      title: l10n.vehicleTitle,
      intro: l10n.vehicleBody,
      footer: footerFor(widget.frame, l10n, _submit),
      children: [
        RadioGroup<bool>(
          groupValue: _hasCar,
          onChanged: (value) => setState(() => _hasCar = value ?? false),
          child: Column(
            children: [
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: true,
                title: Text(l10n.vehicleYes),
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: false,
                title: Text(l10n.vehicleNo),
              ),
            ],
          ),
        ),
        if (_hasCar) ...[
          const SizedBox(height: UmSpace.s4),
          UmField(
            label: l10n.vehicleConsumptionLabel,
            controller: _consumption,
            help: l10n.vehicleConsumptionHelp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: check(
              VehicleInput.consumption(_consumption.text),
              VehicleInput.consumptionMin,
              VehicleInput.consumptionMax,
            ),
          ),
          const SizedBox(height: UmSpace.s4),
          UmField(
            label: l10n.vehicleSeatsLabel,
            controller: _seats,
            keyboardType: TextInputType.number,
            error: check(
              VehicleInput.seats(_seats.text),
              VehicleInput.seatsMin,
              VehicleInput.seatsMax,
            ),
          ),
          const SizedBox(height: UmSpace.s4),
          UmField(
            label: l10n.vehicleDetourLabel,
            controller: _detour,
            help: l10n.vehicleDetourHelp,
            keyboardType: TextInputType.number,
            error: check(
              VehicleInput.detour(_detour.text),
              VehicleInput.detourMin,
              VehicleInput.detourMax,
            ),
          ),
        ],
        ...errorFor(l10n),
      ],
    );
  }
}

class RoleForm extends ConsumerStatefulWidget {
  const RoleForm({super.key, required this.me, required this.frame});

  final Me me;
  final ProfileFormFrame frame;

  @override
  ConsumerState<RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends ConsumerState<RoleForm> with SubmitStateMixin {
  late RoleMode _mode = widget.me.roleMode;

  void _submit() => run(() async {
    if (widget.me.vehicle != null && _mode != widget.me.roleMode) {
      await ref.read(meProvider.notifier).setRoleMode(_mode);
    }
    await widget.frame.onDone();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasVehicle = widget.me.vehicle != null;

    return UmPage(
      appBar: widget.frame.appBar,
      overline: widget.frame.overline,
      title: l10n.roleTitle,
      intro: hasVehicle ? l10n.roleBody : null,
      footer: footerFor(widget.frame, l10n, _submit),
      children: [
        if (hasVehicle)
          RadioGroup<RoleMode>(
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value ?? _mode),
            child: Column(
              children: [
                RadioListTile<RoleMode>(
                  contentPadding: EdgeInsets.zero,
                  value: RoleMode.auto,
                  title: Row(
                    children: [
                      Flexible(child: Text(l10n.roleAuto)),
                      IconButton(
                        tooltip: l10n.roleAutoInfoTooltip,
                        icon: Icon(Icons.info_outline_rounded, color: context.umColors.brandStrong),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(l10n.roleAuto),
                            content: Text(l10n.roleAutoInfo),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: Text(l10n.understood),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                RadioListTile<RoleMode>(
                  contentPadding: EdgeInsets.zero,
                  value: RoleMode.alwaysDriver,
                  title: Text(l10n.roleDriver),
                ),
                RadioListTile<RoleMode>(
                  contentPadding: EdgeInsets.zero,
                  value: RoleMode.alwaysPassenger,
                  title: Text(l10n.rolePassenger),
                ),
              ],
            ),
          )
        else
          UmCard(body: l10n.roleNoVehicle),
        ...errorFor(l10n),
      ],
    );
  }
}
