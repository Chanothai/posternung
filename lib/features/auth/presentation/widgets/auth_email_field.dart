import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Labeled email input shared by login and register.
class AuthEmailField extends StatelessWidget {
  const AuthEmailField({
    required this.controller,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;

  /// Requests focus (and raises the keyboard) on first build — set by the
  /// screen that owns this as its primary field.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            AppStrings.authMethodEmailTab,
            style: AppTextStyles.inputLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: AppTextStyles.inputText,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            hintText: AppStrings.authEmailHint,
            hintStyle: AppTextStyles.inputText.copyWith(
              color: AppColors.placeholderGray,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SvgPicture.asset(
                AppImages.emailIcon,
                width: 14,
                height: 16,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: const BorderSide(color: AppColors.borderMuted),
            ),
          ),
          validator: (value) {
            if (value == null || !value.contains('@')) {
              return AppStrings.authEmailValidationError;
            }
            return null;
          },
        ),
      ],
    );
  }
}
