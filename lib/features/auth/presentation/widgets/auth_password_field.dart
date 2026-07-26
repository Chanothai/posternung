import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Labeled password input (with obscure toggle) shared by login and
/// register. The "forgot password?" link only makes sense on login, so it's
/// gated by [showForgotPassword].
class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
    required this.showForgotPassword,
    super.key,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool showForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.authPasswordLabel,
                style: AppTextStyles.inputLabel,
              ),
              if (showForgotPassword)
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(AppStrings.comingSoonMessage),
                      ),
                    );
                  },
                  child: Text(
                    AppStrings.authForgotPassword,
                    style: AppTextStyles.linkSmall,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          autofillHints: const [AutofillHints.password],
          style: AppTextStyles.inputText,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            hintText: AppStrings.authPasswordHint,
            hintStyle: AppTextStyles.inputText.copyWith(
              color: AppColors.placeholderGray,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SvgPicture.asset(
                AppImages.lockIcon,
                width: 14,
                height: 16,
              ),
            ),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: obscure
                  ? SvgPicture.asset(AppImages.eyeIcon, width: 20, height: 16)
                  : const Icon(Icons.visibility, color: AppColors.accent),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: const BorderSide(color: AppColors.borderMuted),
            ),
          ),
          validator: (value) {
            if (value == null || value.length < 6) {
              return AppStrings.authPasswordValidationError;
            }
            return null;
          },
        ),
      ],
    );
  }
}
