import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/shared/app_icons.dart';

/// Custom Navigation Bar matching the design prototype exactly
/// - 4 items: กลุ่ม, เพื่อน, แจ้งเตือน, โปรไฟล์
/// - Icon on top, text below (vertical layout)
/// - Selected: blue icon + horizontal bar on top
/// - Animated transitions when switching tabs
class ScaffoldWithNavBar extends StatelessWidget {
  final Widget navigationShell;

  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    final shell = navigationShell as StatefulNavigationShell;
    final currentIndex = shell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: AppIcons.groups,
                  activeIcon: AppIcons.groups,
                  label: 'กลุ่ม',
                  isActive: currentIndex == 0,
                  onTap: () => _onTap(shell, 0),
                ),
                _NavItem(
                  icon: AppIcons.friends,
                  activeIcon: AppIcons.friends,
                  label: 'เพื่อน',
                  isActive: currentIndex == 1,
                  onTap: () => _onTap(shell, 1),
                ),
                _NavItem(
                  icon: AppIcons.notifications,
                  activeIcon: AppIcons.notifications,
                  label: 'แจ้งเตือน',
                  isActive: currentIndex == 2,
                  onTap: () => _onTap(shell, 2),
                ),
                _NavItem(
                  icon: AppIcons.profile,
                  activeIcon: AppIcons.profile,
                  label: 'โปรไฟล์',
                  isActive: currentIndex == 3,
                  onTap: () => _onTap(shell, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(StatefulNavigationShell shell, int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  static const _animationDuration = Duration(milliseconds: 200);
  static const _animationCurve = Curves.easeInOut;
  static const activeColor = Color(0xFF81CEF2);

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.grey[400];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated horizontal indicator bar on TOP
            AnimatedContainer(
              duration: _animationDuration,
              curve: _animationCurve,
              height: 3,
              width: isActive ? 40 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // Animated icon with color and scale
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: isActive ? 1.1 : 1.0),
              duration: _animationDuration,
              curve: _animationCurve,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: AnimatedSwitcher(
                    duration: _animationDuration,
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      color: isActive ? activeColor : inactiveColor,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            // Animated label text
            AnimatedDefaultTextStyle(
              duration: _animationDuration,
              curve: _animationCurve,
              style: TextStyle(
                fontFamily: 'LINESeedSansTH',
                color: isActive ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
