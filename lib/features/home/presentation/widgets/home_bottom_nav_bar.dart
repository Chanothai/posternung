import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'home_coming_soon.dart';

/// Fixed bottom tab bar. Home is the active tab (no-op); Search/Wishlist/
/// Cart show a coming-soon snackbar; Profile signs the user out.
///
/// Figma: node 7:207, frame "Nav - Bottom Tab Bar".
class HomeBottomNavBar extends ConsumerWidget {
  const HomeBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.glassCardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 13, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavTab(
                assetName: 'assets/images/nav_home_icon.svg',
                iconSize: const Size(20.25, 18),
                label: 'Home',
                labelColor: AppColors.accent,
                onTap: () {},
              ),
              _NavTab(
                assetName: 'assets/images/nav_search_icon.svg',
                iconSize: const Size(18, 18),
                label: 'Search',
                onTap: () => showComingSoonSnackBar(context),
              ),
              _NavTab(
                assetName: 'assets/images/nav_wishlist_icon.svg',
                iconSize: const Size(18, 18),
                label: 'Wishlist',
                onTap: () => showComingSoonSnackBar(context),
              ),
              _NavTab(
                assetName: 'assets/images/nav_cart_icon.svg',
                iconSize: const Size(15.75, 18),
                label: 'Cart',
                showDot: true,
                onTap: () => showComingSoonSnackBar(context),
              ),
              _NavTab(
                assetName: 'assets/images/nav_profile_icon.svg',
                iconSize: const Size(15.75, 18),
                label: 'Profile',
                onTap: () => ref.read(authViewModelProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.assetName,
    required this.iconSize,
    required this.label,
    required this.onTap,
    this.labelColor = AppColors.textPrimary,
    this.showDot = false,
  });

  final String assetName;
  final Size iconSize;
  final String label;
  final Color labelColor;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 32,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    assetName,
                    width: iconSize.width,
                    height: iconSize.height,
                  ),
                  if (showDot)
                    Positioned(
                      top: 0,
                      right: 8,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accentRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceDark,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.homeNavTabLabel.copyWith(color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}
