import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../auth_error_display.dart';

/// Friendly Thai error message + a muted raw error code, shown below an
/// auth form's fields when submission fails.
///
/// [onRetry], when given, only ever renders a button for
/// [oauthLoginConflictCode] (ADR-0021 D3) — "the button is tied to the
/// code, not to the screen": every screen that shows this banner gets the
/// same behavior for free, and no other code gets a button even if
/// [onRetry] is supplied.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    required this.message,
    this.code,
    this.onRetry,
    super.key,
  });

  final String message;
  final String? code;

  /// Retries whatever action produced this error. Ignored unless [code] is
  /// [oauthLoginConflictCode] — see the class doc.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final showRetry = onRetry != null && code == oauthLoginConflictCode;
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
        if (showRetry) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onRetry,
            child: Text(AppStrings.authRetryButton),
          ),
        ],
      ],
    );
  }
}
