import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../achievements/presentation/achievements_controller.dart';
import '../../achievements/presentation/badge_medal.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../notifications/presentation/push_controller.dart';
import '../../proposals/domain/proposal.dart';
import '../../proposals/presentation/formatting.dart';
import '../../rides/presentation/active_ride.dart';
import 'welcome_screen.dart';

/// Onglets de l'app connectée : messages à gauche, accueil au milieu, profil à droite. Le
/// trajet en cours reste visible au-dessus de la barre, quel que soit l'onglet.
class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Push enregistré et messages en direct pendant toute la session.
    ref.watch(pushRegistrationProvider);
    final unread = ref.watch(unreadCountProvider);
    final active = ref.watch(activeRideProvider).value;
    // Badge gagné : célébration au milieu de l'écran, où que l'on soit dans l'app.
    ref.listen(achievementsProvider, (_, next) {
      if (next.value case final achievements?) {
        ref.read(badgeCelebrationsProvider).check(context, achievements);
      }
    });

    void go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sur l'accueil, le trajet en cours est déjà en tête de liste.
          if (active != null && shell.currentIndex != 1) LiveRideBanner(ride: active),
          UmNavBar(
            selected: shell.currentIndex,
            onSelect: go,
            items: [
              UmNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
                label: l10n.navMessages,
                tooltip: unread > 0
                    ? l10n.chatMessagesUnreadTooltip(unread)
                    : l10n.chatMessagesTooltip,
                badge: unread,
              ),
              UmNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                image: const UmLogoCompact(),
                label: l10n.navHome,
                tooltip: l10n.navHome,
              ),
              UmNavItem(
                icon: Icons.account_circle_outlined,
                selectedIcon: Icons.account_circle_rounded,
                label: l10n.navProfile,
                tooltip: l10n.homeProfileTooltip,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UmNavItem {
  const UmNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
    this.badge = 0,
    this.image,
  });

  /// Remplace l'icône (logo compact pour l'accueil).
  final Widget? image;

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;
  final int badge;
}

/// Barre d'onglets : icône au-dessus du libellé, onglet actif dans une pastille.
class UmNavBar extends StatelessWidget {
  const UmNavBar({required this.items, required this.selected, required this.onSelect, super.key});

  final List<UmNavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: UmSpace.s3, vertical: UmSpace.s2),
          child: Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(
                  child: _NavButton(item: item, selected: i == selected, onTap: () => onSelect(i)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final UmNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final color = selected ? c.brandStrong : c.ink;
    final icon =
        item.image ??
        Icon(selected ? item.selectedIcon : item.icon, color: color, size: UmSize.iconMd);
    return Tooltip(
      message: item.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.tooltip,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(UmRadius.lg),
          onTap: onTap,
          child: AnimatedContainer(
            duration: UmMotion.fast,
            constraints: const BoxConstraints(minHeight: UmSize.tapTarget),
            padding: const EdgeInsets.symmetric(vertical: UmSpace.s2, horizontal: UmSpace.s3),
            decoration: BoxDecoration(
              color: selected ? c.lavender : Colors.transparent,
              borderRadius: BorderRadius.circular(UmRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.badge > 0) Badge(label: Text('${item.badge}'), child: icon) else icon,
                const SizedBox(height: UmSpace.s1),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UmText.label.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau du trajet en cours : point qui pulse et accès direct à la carte.
class LiveRideBanner extends StatefulWidget {
  const LiveRideBanner({required this.ride, super.key});

  final Proposal ride;

  @override
  State<LiveRideBanner> createState() => _LiveRideBannerState();
}

class _LiveRideBannerState extends State<LiveRideBanner> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Animations réduites dans les réglages : point fixe.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final ride = widget.ride;
    final role = ride.isDriver ? l10n.badgeDriver : l10n.badgePassenger;
    final title = l10n.liveBannerTitle(role, formatTime(ride.time, l10n.localeName));
    return Material(
      color: c.brandStrong,
      child: InkWell(
        onTap: () => context.push(AppRoutes.ride(ride.id)),
        child: Semantics(
          button: true,
          label: '$title. ${l10n.liveBannerAction}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UmSpace.s5, vertical: UmSpace.s3),
            child: Row(
              children: [
                FadeTransition(
                  opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
                  child: Container(
                    width: UmSize.routeDot,
                    height: UmSize.routeDot,
                    decoration: BoxDecoration(color: c.onBrand, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: UmSpace.s3),
                Expanded(
                  child: Text(
                    title,
                    style: UmText.button.copyWith(color: c.onBrand),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: UmSpace.s3),
                Text(l10n.liveBannerAction, style: UmText.button.copyWith(color: c.onBrand)),
                Icon(Icons.chevron_right_rounded, color: c.onBrand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
