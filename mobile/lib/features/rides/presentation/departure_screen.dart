import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../../proposals/presentation/formatting.dart';
import '../data/nav_launcher.dart';
import '../domain/ride.dart';
import 'live_actions.dart';
import 'live_controller.dart';
import 'rides_controller.dart';

/// Écran « Départ » du conducteur (cahier §15) : arrêts dans l'ordre, démarrage, navigation
/// dans son application GPS (choix mémorisé), « monté » pour chaque passager, clôture.
class DepartureScreen extends ConsumerStatefulWidget {
  const DepartureScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DepartureScreen> createState() => _DepartureScreenState();
}

class _DepartureScreenState extends ConsumerState<DepartureScreen> {
  String? _busy;
  String? _errorCode;
  ProviderSubscription<LiveState>? _live;

  /// Suivi en direct gardé ouvert tant que l'écran est affiché (fermé avec lui).
  void _keepLive() => _live ??= ref.listenManual(liveRideProvider(widget.id), (_, _) {});

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() {
      _busy = key;
      _errorCode = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _start() => _run('start', () async {
    await ref.read(rideProvider(widget.id).notifier).start();
    // Le suivi s'ouvre : le conducteur partage sa position (après explication).
    _keepLive();
    if (mounted) await shareLocation(context, ref, widget.id);
  });

  Future<NavApp?> _pickApp({bool force = false}) async {
    final saved = NavApp.fromWire(ref.read(meProvider).value?.defaultNavApp);
    final installed = await ref.read(navLauncherProvider).installed();
    if (!force && saved != null && installed.contains(saved)) return saved;
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<NavApp>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(UmSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.navAppChoose,
                  style: UmText.h3.copyWith(color: context.umColors.ink),
                ),
              ),
              const SizedBox(height: UmSpace.s3),
              if (installed.isEmpty) Text(l10n.navAppNone),
              for (final app in installed)
                Padding(
                  padding: const EdgeInsets.only(bottom: UmSpace.s2),
                  child: UmButton(
                    label: navAppName(l10n, app),
                    variant: UmButtonVariant.secondary,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(app),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await ref.read(meProvider.notifier).setDefaultNavApp(picked.wire);
    return picked;
  }

  Future<void> _navigate({bool changeApp = false}) async {
    // Choix de l'application d'abord (feuille), le chargement ensuite.
    final app = await _pickApp(force: changeApp);
    if (app == null || !mounted) return;
    await _run('nav', () async {
      final plan = await ref.read(navigationProvider(widget.id).future);
      final opened = await ref.read(navLauncherProvider).open(plan.linkFor(app));
      if (!opened && mounted) setState(() => _errorCode = 'nav_open_failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final ride = ref.watch(rideProvider(widget.id));
    final plan = ref.watch(navigationProvider(widget.id));
    final details = ride.value;
    final navigation = plan.value;

    if (details == null || navigation == null) {
      final error = ride.error ?? plan.error;
      return UmPage(
        appBar: AppBar(),
        title: l10n.departureTitle,
        children: [
          if (error != null) ...[
            UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
            const SizedBox(height: UmSpace.s3),
            UmButton(
              label: l10n.retry,
              variant: UmButtonVariant.ghost,
              onPressed: () {
                ref.invalidate(rideProvider(widget.id));
                ref.invalidate(navigationProvider(widget.id));
              },
            ),
          ] else
            Semantics(
              label: l10n.loading,
              child: LinearProgressIndicator(color: c.brand),
            ),
        ],
      );
    }

    final inProgress = details.inProgress;
    if (inProgress) _keepLive();
    final savedApp = NavApp.fromWire(ref.watch(meProvider.select((m) => m.value?.defaultNavApp)));
    final waze = savedApp == NavApp.waze;

    return UmPage(
      appBar: AppBar(),
      title: l10n.departureTitle,
      intro: inProgress ? null : l10n.departureIntro,
      footer: [
        if (details.editable)
          UmButton(
            label: l10n.startRide,
            expand: true,
            loading: _busy == 'start',
            onPressed: _busy == null ? _start : null,
          )
        else if (inProgress) ...[
          UmButton(
            label: waze && navigation.remaining.length > 1 ? l10n.nextStop : l10n.launchNavigation,
            icon: Icons.navigation_outlined,
            expand: true,
            loading: _busy == 'nav',
            onPressed: _busy == null ? _navigate : null,
          ),
          UmButton(
            label: l10n.changeNavApp,
            variant: UmButtonVariant.secondary,
            expand: true,
            onPressed: _busy == null ? () => _navigate(changeApp: true) : null,
          ),
          UmButton(
            label: l10n.finishRide,
            variant: UmButtonVariant.ghost,
            expand: true,
            onPressed: _busy == null
                ? () => _run('finish', () => ref.read(rideProvider(widget.id).notifier).finish())
                : null,
          ),
        ],
      ],
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: inProgress
              ? UmChip(
                  label: l10n.rideInProgress,
                  icon: Icons.near_me_outlined,
                  tone: UmChipTone.success,
                )
              : UmChip(
                  label: l10n.proposalConfirmed,
                  icon: Icons.check_circle_outline_rounded,
                  tone: UmChipTone.success,
                ),
        ),
        if (waze && inProgress) ...[
          const SizedBox(height: UmSpace.s3),
          Text(l10n.wazeStopByStop, style: UmText.bodySm.copyWith(color: c.inkMuted)),
        ],
        const SizedBox(height: UmSpace.s5),
        for (final stop in navigation.stops)
          _DepartureStop(
            stop: stop,
            // La destination n'a pas d'utilisateur : jamais « en cours » ni « monté ».
            busy: stop.userId != null && _busy == stop.userId,
            onPickedUp: inProgress && !stop.isDestination && !stop.pickedUp && _busy == null
                ? () => _run(
                    stop.userId!,
                    () => ref.read(rideProvider(widget.id).notifier).pickedUp(stop.userId!),
                  )
                : null,
          ),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(
            _errorCode == 'nav_open_failed'
                ? l10n.navOpenFailed
                : apiErrorMessage(l10n, _errorCode),
          ),
        ],
      ],
    );
  }
}

String navAppName(AppLocalizations l10n, NavApp app) => switch (app) {
  NavApp.googleMaps => l10n.navAppGoogleMaps,
  NavApp.waze => l10n.navAppWaze,
  NavApp.appleMaps => l10n.navAppAppleMaps,
};

class _DepartureStop extends StatelessWidget {
  const _DepartureStop({required this.stop, required this.busy, this.onPickedUp});

  final NavigationStop stop;
  final bool busy;
  final VoidCallback? onPickedUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final name = stop.isDestination ? l10n.destination : stop.firstName ?? '';
    final time = stop.eta == null ? null : formatTime(stop.eta!, l10n.localeName);
    return Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: UmSize.stopBadge,
              height: UmSize.stopBadge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stop.isDestination ? c.brandStrong : c.surfaceRaised,
                border: stop.isDestination
                    ? null
                    : Border.all(color: c.brandStrong, width: UmSize.routeRing),
              ),
              child: stop.isDestination
                  ? Icon(Icons.flag_outlined, size: UmSize.iconSm, color: c.onBrand)
                  : Text('${stop.order}', style: UmText.label.copyWith(color: c.brandStrong)),
            ),
          ),
          const SizedBox(width: UmSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                ),
                Text(stop.label, style: UmText.bodySm.copyWith(color: c.inkMuted)),
                if (time != null)
                  Text(l10n.rideStopAround(time), style: UmText.bodySm.copyWith(color: c.ink)),
                if (stop.pickedUp) ...[
                  const SizedBox(height: UmSpace.s1),
                  UmChip(label: l10n.pickedUp, icon: Icons.check_rounded, tone: UmChipTone.success),
                ],
              ],
            ),
          ),
          if (onPickedUp != null || busy)
            Semantics(
              label: l10n.pickedUpSemantic(name),
              button: true,
              excludeSemantics: true,
              child: UmButton(
                label: l10n.markPickedUp,
                variant: UmButtonVariant.secondary,
                loading: busy,
                onPressed: onPickedUp,
              ),
            ),
        ],
      ),
    );
  }
}
