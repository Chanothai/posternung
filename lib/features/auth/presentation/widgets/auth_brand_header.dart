import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Brand row (logo + app name) shown above the auth card on login/register.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            AppImages.headerIcon,
            width: AppDimens.iconLg,
            height: AppDimens.iconLg,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(AppStrings.appName, style: AppTextStyles.brandTitleLarge),
        ],
      ),
    );
  }
}
