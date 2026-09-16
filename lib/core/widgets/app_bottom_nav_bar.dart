import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../assets/app_images.dart';
import '../design_system/app_dimens.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../router/app_routes.dart';
import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The app's fixed 3-tab bottom navigation — Home / คำสั่งซื้อของฉัน /
/// โปรไฟล์ (`ADR-0037` Amendment 1 · Amendment 4 A4-D2 #6 — a temporary nav
/// until the deferred tabs get a schema and an endpoint behind them).
///
/// Lives in `core/widgets/` rather than `features/home/`, where it used to
/// be as `HomeBottomNavBar`: it is now the bottom bar for three separate
/// screens across three different features (`HomeScreen`,
/// `OrdersPlaceholderScreen`, `ProfileScreen`), so it can't stay owned by
/// any one of them without the other two reaching into `features/home/`
/// for it — exactly what `core/CLAUDE.md`'s "core imports nothing from
/// features/" rule exists to prevent. Routes only through [AppRoutes] /
/// `context.go`, never a widget name from `features/`.
///
/// 🔴 Cut from 5 tabs to 3 (search/wishlist/cart removed, not hidden — no
/// curation table, no wishlist table, no cart endpoint behind any of them;
/// `ADR-0030` also deleted cart from the contract outright) and the
/// Profile tab **no longer signs out on tap**. It used to be
/// `onTap: () => ref.read(authViewModelProvider.notifier).signOut()`
/// directly on the nav bar — one stray tap on the bottom bar logged the
/// user out with no confirmation. It now navigates to `/profile`, where
/// signing out is a deliberate, confirmed action (see `ProfileScreen`).
///
/// The active tab is read from the current location
/// (`GoRouterState.of(context).uri.path`) rather than passed in: every
/// screen this bar appears on already sits inside a `GoRoute`'s subtree
/// (it is only ever used as a `Scaffold.bottomNavigationBar`), so there is
/// always a real answer and no risk of a caller passing a stale one.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.glassCardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavTab(
                assetName: AppImages.navHomeIcon,
                assetSize: const Size(20.25, 18),
                label: AppStrings.homeNavHome,
                active: location == AppRoutes.homePath,
                onTap: () => context.go(AppRoutes.homePath),
              ),
              _NavTab(
                icon: Icons.receipt_long_outlined,
                label: AppStrings.homeNavOrders,
                active: location == AppRoutes.ordersPath,
                onTap: () => context.go(AppRoutes.ordersPath),
              ),
              _NavTab(
                assetName: AppImages.navProfileIcon,
                assetSize: const Size(15.75, 18),
                label: AppStrings.homeNavProfile,
                active: location == AppRoutes.profilePath,
                onTap: () => context.go(AppRoutes.profilePath),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab. Renders from either an [assetName] (existing Figma svg icons,
/// home/profile) or an [icon] (the orders tab's `Icons.receipt_long_outlined`
/// — not waiting on a Figma-exported asset, per GATE 1's decision #10).
/// Exactly one of the two must be given.
class _NavTab extends StatelessWidget {
  const _NavTab({
    this.assetName,
    this.assetSize = const Size(AppDimens.iconSm, AppDimens.iconSm),
    this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  }) : assert(
         (assetName == null) != (icon == null),
         'Give _NavTab exactly one of assetName or icon.',
       );

  final String? assetName;
  final Size assetSize;
  final IconData? icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? AppColors.accent : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 32,
              child: Center(
                child: assetName != null
                    ? SvgPicture.asset(
                        assetName!,
                        width: assetSize.width,
                        height: assetSize.height,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      )
                    : Icon(icon, size: AppDimens.iconSm, color: color),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.homeNavTabLabel.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
