import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'home_coming_soon.dart';

/// Top bar: logo + title, cart button, and a (visual-only) search bar.
///
/// Figma: node 7:245, frame "Header / Top Bar".
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(bottom: BorderSide(color: AppColors.borderMuted)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/header_icon.svg',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.homeBrandTitle,
                      style: AppTextStyles.appBarTitle,
                    ),
                  ],
                ),
                _CartButton(onPressed: () => showComingSoonSnackBar(context)),
              ],
            ),
            const SizedBox(height: 16),
            _HomeSearchBar(onTap: () => showComingSoonSnackBar(context)),
          ],
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.glassCardFill,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.glassCardBorder),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/cart_icon.svg',
                  width: 15.75,
                  height: 14,
                ),
              ),
            ),
          ),
          Positioned(
            top: -5.5,
            right: -4,
            child: Container(
              width: 16,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentRed,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceDark, width: 2),
              ),
              child: Text('3', style: AppTextStyles.homeBadgeLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 41),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.borderMuted),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Text(
              AppStrings.homeSearchPlaceholder,
              style: AppTextStyles.homeSearchPlaceholder,
            ),
            Positioned(
              left: -29,
              child: SvgPicture.asset(
                'assets/images/search_icon.svg',
                width: 14,
                height: 14,
              ),
            ),
            Positioned(
              right: -29,
              child: SvgPicture.asset(
                'assets/images/filter_icon.svg',
                width: 14,
                height: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
