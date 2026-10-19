import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/appearance.dart';
import '../../../core/theme/um_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/achievements.dart';
import 'achievement_labels.dart';

/// Teinte propre à chaque badge (médaille colorée, comme sur les applis de covoiturage) ; assez
/// soutenue pour que l'icône claire reste lisible dessus.
Color badgeColor(BuildContext context, String key) {
  const hues = {
    'first_ride': 14.0,
    'ten_rides': 210.0,
    'fifty_rides': 45.0,
    'loyal_driver': 265.0,
    'full_week': 330.0,
    'sociable': 175.0,
    'eco': 135.0,
    'reliable': 230.0,
  };
  final dark = Theme.of(context).brightness == Brightness.dark;
  return HSLColor.fromAHSL(1, hues[key] ?? 260, 0.7, dark ? 0.5 : 0.42).toColor();
}

/// Médaille d'un badge : ruban, bord, disque et icône. Pas encore gagné : grisé avec un cadenas.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.badgeKey, required this.earned, this.size = 48});

  final String badgeKey;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final color = earned ? badgeColor(context, badgeKey) : c.inkMuted;
    final light = Color.lerp(color, c.onBrand, 0.35)!;
    final ribbon = Color.lerp(color, c.ink, 0.25)!;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ruban en V derrière la médaille.
          for (final side in [-1.0, 1.0])
            Positioned(
              top: 0,
              left: size / 2 - size * 0.16 + side * size * 0.14,
              child: Transform.rotate(
                angle: side * 0.35,
                child: Container(
                  width: size * 0.32,
                  height: size * 0.55,
                  color: earned ? ribbon : c.border,
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.84,
              height: size * 0.84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [light, color],
                  center: const Alignment(-0.3, -0.4),
                ),
                border: Border.all(color: light, width: size * 0.05),
                boxShadow: earned ? context.umShadowSoft : null,
              ),
              child: Icon(
                earned ? badgeIcon(badgeKey) : Icons.lock_outline_rounded,
                size: size * 0.4,
                color: c.onBrand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Médaille en 3D : elle tourne sur elle-même (glisser pour la faire tourner), l'envers porte
/// le nom du badge.
class SpinningMedal extends StatefulWidget {
  const SpinningMedal({
    super.key,
    required this.badgeKey,
    required this.earned,
    this.size = 220,
    this.intro = true,
  });

  final String badgeKey;
  final bool earned;
  final double size;

  /// Quelques tours à l'ouverture.
  final bool intro;

  @override
  State<SpinningMedal> createState() => _SpinningMedalState();
}

class _SpinningMedalState extends State<SpinningMedal> with SingleTickerProviderStateMixin {
  late final _angle = AnimationController.unbounded(vsync: this);
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (!_still && widget.intro && _angle.value == 0) {
      _angle.animateTo(
        math.pi * 4,
        duration: const Duration(milliseconds: 1800),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _angle.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails details) {
    _angle.value += details.delta.dx / widget.size * math.pi;
  }

  /// Lâchée : elle continue sur sa lancée (lancer à la main), ralentit puis se pose face visible.
  void _release(DragEndDetails details) {
    if (_still) {
      _settle(0);
      return;
    }
    final velocity = details.velocity.pixelsPerSecond.dx / widget.size * math.pi;
    if (velocity.abs() < 1) {
      _settle(velocity);
      return;
    }
    _angle
        .animateWith(FrictionSimulation(0.35, _angle.value, velocity, tolerance: _slow))
        .then((_) => _settle(_slow.velocity * velocity.sign));
  }

  static const _slow = Tolerance(velocity: 2);

  /// Pose la médaille sur la face la plus proche dans le sens où elle tourne.
  void _settle(double velocity) {
    final turn = 2 * math.pi;
    final rest = velocity == 0
        ? (_angle.value / turn).round() * turn
        : (velocity > 0 ? (_angle.value / turn).ceil() : (_angle.value / turn).floor()) * turn;
    if (_still) {
      _angle.value = rest;
      return;
    }
    _angle.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 60, ratio: 0.75),
        _angle.value,
        rest,
        velocity,
      ),
    );
  }

  /// Toucher : un tour complet.
  void _spinOnce() {
    final turn = 2 * math.pi;
    final target = ((_angle.value / turn).round() + 1) * turn;
    if (_still) {
      _angle.value = target;
      return;
    }
    _angle.animateTo(
      target,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final color = widget.earned ? badgeColor(context, widget.badgeKey) : c.inkMuted;
    return Semantics(
      image: true,
      label: badgeName(l10n, widget.badgeKey),
      hint: l10n.badgeSpinHint,
      child: GestureDetector(
        onTap: _spinOnce,
        onHorizontalDragStart: (_) => _angle.stop(),
        onHorizontalDragUpdate: _drag,
        onHorizontalDragEnd: _release,
        child: AnimatedBuilder(
          animation: _angle,
          builder: (context, _) {
            final angle = _angle.value;
            final back = math.cos(angle) < 0;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle),
              child: back
                  // Envers : retourné pour se lire à l'endroit, avec le nom du badge.
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: Container(
                        width: widget.size * 0.84,
                        height: widget.size * 0.84,
                        margin: EdgeInsets.only(top: widget.size * 0.16),
                        padding: EdgeInsets.all(widget.size * 0.12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(color, c.ink, 0.2),
                          border: Border.all(
                            color: Color.lerp(color, c.onBrand, 0.35)!,
                            width: widget.size * 0.05,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeName(l10n, widget.badgeKey),
                          textAlign: TextAlign.center,
                          style: UmText.h3.copyWith(color: c.onBrand),
                        ),
                      ),
                    )
                  : BadgeMedal(badgeKey: widget.badgeKey, earned: widget.earned, size: widget.size),
            );
          },
        ),
      ),
    );
  }
}

/// Badge en grand, au milieu de l'écran : il tourne, on le fait tourner du doigt. `celebrate` :
/// il vient d'être gagné (titre, halo qui pulse).
Future<void> showBadgeViewer(
  BuildContext context,
  AchievementBadge badge, {
  bool celebrate = false,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context).close,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => _BadgeViewer(badge: badge, celebrate: celebrate),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _BadgeViewer extends StatefulWidget {
  const _BadgeViewer({required this.badge, required this.celebrate});

  final AchievementBadge badge;
  final bool celebrate;

  @override
  State<_BadgeViewer> createState() => _BadgeViewerState();
}

class _BadgeViewerState extends State<_BadgeViewer> with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _glow.value = 0.5;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final b = widget.badge;
    final color = b.earned ? badgeColor(context, b.key) : c.inkMuted;
    final route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Fond : l'écran derrière, flouté et adouci ; toucher ferme.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(color: c.surface.withValues(alpha: 0.6)),
              ),
            ),
          ),
          // Mise en avant : un halo de la couleur du badge qui respire.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _glow,
                builder: (context, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.75 + 0.1 * _glow.value,
                      colors: [
                        color.withValues(alpha: 0.35 + 0.15 * _glow.value),
                        color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.7,
                  end: 1,
                ).animate(CurvedAnimation(parent: route, curve: Curves.easeOutBack)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(UmSpace.s6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.celebrate) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.badgeWonTitle,
                            textAlign: TextAlign.center,
                            style: UmText.h1.copyWith(color: c.ink),
                          ),
                        ),
                        const SizedBox(height: UmSpace.s5),
                      ],
                      AnimatedBuilder(
                        animation: _glow,
                        builder: (context, child) => DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3 + 0.3 * _glow.value),
                                blurRadius: 30 + 20 * _glow.value,
                                spreadRadius: 2 + 6 * _glow.value,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: SpinningMedal(badgeKey: b.key, earned: b.earned),
                      ),
                      const SizedBox(height: UmSpace.s6),
                      Text(
                        badgeName(l10n, b.key),
                        textAlign: TextAlign.center,
                        style: UmText.h2.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: UmSpace.s2),
                      Text(
                        badgeGoal(l10n, b.key),
                        textAlign: TextAlign.center,
                        style: UmText.body.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: UmSpace.s2),
                      Text(
                        b.earned ? l10n.badgeEarned : l10n.badgeProgress(b.progress, b.goal),
                        style: UmText.label.copyWith(color: c.brandStrong),
                      ),
                      const SizedBox(height: UmSpace.s5),
                      Text(l10n.badgeSpinHint, style: UmText.caption.copyWith(color: c.inkMuted)),
                      const SizedBox(height: UmSpace.s4),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.close,
                          style: UmText.button.copyWith(color: c.brandStrong),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _seenKey = 'badges.seen';

/// Badges gagnés depuis la dernière fois : la médaille s'affiche au milieu de l'écran et tourne.
/// Les badges vus sont gardés sur le téléphone ; une seule célébration à la fois.
class BadgeCelebrations {
  BadgeCelebrations(this._prefs);

  final PrefsStore _prefs;
  bool _showing = false;

  Future<void> check(BuildContext context, Achievements achievements) async {
    if (_showing) return;
    final earned = achievements.badges.where((b) => b.earned).toList();
    final stored = await _prefs.read(_seenKey);
    // Première lecture sur ce téléphone : on mémorise sans fêter (pas d'avalanche à
    // l'installation) ; seuls les badges gagnés ensuite ont leur animation.
    if (stored == null) {
      await _prefs.write(_seenKey, earned.map((b) => b.key).join(','));
      return;
    }
    final seen = stored.split(',').where((k) => k.isNotEmpty).toSet();
    final fresh = earned.where((b) => !seen.contains(b.key)).toList();
    if (fresh.isEmpty || !context.mounted) return;
    _showing = true;
    await _prefs.write(_seenKey, earned.map((b) => b.key).join(','));
    try {
      if (context.mounted) await showBadgeViewer(context, fresh.last, celebrate: true);
    } finally {
      _showing = false;
    }
  }
}

final badgeCelebrationsProvider = Provider<BadgeCelebrations>(
  (ref) => BadgeCelebrations(ref.watch(prefsStoreProvider)),
);
