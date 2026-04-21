import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/navigation/route_names.dart';
import '../core/localization/localization_helper.dart';

/// Bottom Navigation Bar - Liquid Glass Effect
class BottomNav extends StatelessWidget {
  final String activeTab;

  const BottomNav({
    super.key,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final sidePadding = isCompact ? 12.0 : 24.0;
    final navInnerPadding = isCompact ? 4.0 : 8.0;
    final centerGap = isCompact ? 2.0 : 4.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: sidePadding,
          right: sidePadding,
          top: 16,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: navInnerPadding, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.surface.withValues(
                          alpha: isDark ? 0.88 : 0.85,
                        ),
                        colorScheme.surface.withValues(
                          alpha: isDark ? 0.78 : 0.75,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        blurRadius: 40,
                        offset: const Offset(0, 4),
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _NavItem(
                          icon: Icons.home_rounded,
                          label: context.l10n.home,
                          id: 'home',
                          activeTab: activeTab,
                          isCompact: isCompact,
                          onTap: () => context.go(RouteNames.home),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.grid_view_rounded,
                          label: context.l10n.courses,
                          id: 'courses',
                          activeTab: activeTab,
                          isCompact: isCompact,
                          onTap: () => context.go(RouteNames.allCourses),
                        ),
                      ),
                      SizedBox(width: centerGap),
                      _CenterNavItem(
                        activeTab: activeTab,
                        isCompact: isCompact,
                        onTap: () => context.go(RouteNames.progress),
                      ),
                      SizedBox(width: centerGap),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.menu_book_rounded,
                          label: context.l10n.myCourses,
                          id: 'enrolled',
                          activeTab: activeTab,
                          isCompact: isCompact,
                          onTap: () => context.go(RouteNames.enrolled),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.person_rounded,
                          label: context.l10n.myAccount,
                          id: 'dashboard',
                          activeTab: activeTab,
                          isCompact: isCompact,
                          onTap: () => context.go(RouteNames.dashboard),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String id;
  final String activeTab;
  final bool isCompact;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.id,
    required this.activeTab,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = activeTab == id;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? (isCompact ? 4 : 8) : (isCompact ? 3 : 6),
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.15),
                    colorScheme.primary.withValues(alpha: 0.08),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                icon,
                size: isCompact ? (isActive ? 24 : 22) : (isActive ? 26 : 24),
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isCompact ? 2 : 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize:
                    isCompact ? (isActive ? 10 : 9) : (isActive ? 11 : 10),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterNavItem extends StatelessWidget {
  final String activeTab;
  final bool isCompact;
  final VoidCallback onTap;

  const _CenterNavItem({
    required this.activeTab,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = activeTab == 'progress';
    final primaryDeep = Color.lerp(
      colorScheme.primary,
      colorScheme.shadow,
      0.28,
    )!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isCompact ? 52 : 56,
        height: isCompact ? 52 : 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              primaryDeep,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? colorScheme.onPrimary.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: Icon(
            Icons.insights_rounded,
            color: colorScheme.onPrimary,
            size: 26,
          ),
        ),
      ),
    );
  }
}
