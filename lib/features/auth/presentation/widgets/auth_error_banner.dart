import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Friendly Thai error message + a muted raw error code, shown below an
/// auth form's fields when submission fails.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, this.code, super.key});

  final String message;
  final String? code;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          style: AppTextStyles.cardSubtitle.copyWith(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
        if (code != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${AppStrings.authErrorCodeLabel}$code',
            style: AppTextStyles.linkSmall.copyWith(
              color: AppColors.placeholderGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
