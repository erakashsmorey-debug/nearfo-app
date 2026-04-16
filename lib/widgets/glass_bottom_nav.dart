import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../l10n/l10n_helper.dart';

/// Premium glass-morphism bottom navigation bar using BackdropFilter.
/// Replaces the default BottomNavigationBar with a frosted-glass effect,
/// animated active indicator dots, and gradient unread badges.
class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final int unreadChatCount;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.unreadChatCount,
    required this.onTap,
  });

  // Note: Labels will be translated at runtime in build method
  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded, label: 'navHome'),
    _NavItem(icon: Icons.slow_motion_video_rounded, label: 'navReels'),
    _NavItem(icon: Icons.explore_rounded, label: 'navDiscover'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: 'navChat'),
    _NavItem(icon: Icons.person_rounded, label: 'navProfile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 8,
            bottom: bottomPadding > 8 ? bottomPadding : 8,
          ),
          decoration: BoxDecoration(
            color: NearfoColors.bg.withOpacity(0.85),
            border: Border(
              top: BorderSide(color: NearfoColors.border),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isActive = index == currentIndex;
              final hasBadge = item.label == 'Chat' && unreadChatCount > 0;

              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with optional badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: isActive
                                ? NearfoColors.primaryLight
                                : NearfoColors.textDim,
                          ),
                          if (hasBadge)
                            Positioned(
                              top: -4,
                              right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                constraints: const BoxConstraints(minWidth: 18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  gradient: NearfoColors.primaryGradient,
                                  border: Border.all(
                                      color: NearfoColors.bg, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    unreadChatCount > 99
                                        ? '99+'
                                        : '$unreadChatCount',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Label
                      Text(
                        _getNavLabel(context, item.label),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? NearfoColors.primaryLight
                              : NearfoColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Active indicator dot with glow
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 5 : 0,
                        height: isActive ? 5 : 0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: NearfoColors.primary,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color:
                                        NearfoColors.primary.withOpacity(0.6),
                                    blurRadius: 8,
                                  )
                                ]
                              : [],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  String _getNavLabel(BuildContext context, String key) {
    switch (key) {
      case 'navHome':
        return context.l10n.navHome;
      case 'navReels':
        return context.l10n.navReels;
      case 'navDiscover':
        return context.l10n.navDiscover;
      case 'navChat':
        return context.l10n.navChat;
      case 'navProfile':
        return context.l10n.navProfile;
      default:
        return key;
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
