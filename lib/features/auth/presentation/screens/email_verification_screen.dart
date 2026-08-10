import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/router/app_navigation.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../auth_error_display.dart';
import '../auth_flow_navigation.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_nav_link_row.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';

/// "Waiting for email verification" screen (ADR-0021 D2). Reached two ways:
/// after a successful register, or after a `password`-provider login whose
/// backend exchange answered `403 OAUTH_EMAIL_NOT_VERIFIED`.
///
/// No Figma spec exists for this screen (ADR-0021 §ผลที่ตามมา 🔴) — built
/// from acceptance criteria alone, using the same visual shell every other
/// auth screen uses.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({
    required this.email,
    required this.justSentEmail,
    super.key,
  });

  /// The Firebase account's email address, shown in the subtitle. Display
  /// only — held in `emailVerificationFlowProvider`, not re-read from here
  /// (same reasoning as `OtpVerificationScreen.phoneNumber`).
  final String email;

  /// Whether arriving at this screen was itself the moment a verification
  /// email was sent — true from register (`registerWithEmailPassword` just
  /// called `sendEmailVerification`), false from the login-403 redirect
  /// (`OAUTH_EMAIL_NOT_VERIFIED` — no email was sent as part of *this*
  /// arrival, whatever was sent at register time could be long gone).
  ///
  /// 🔴 Drives whether the resend cooldown starts **armed** (code-critic
  /// GATE 3 round 1): without this distinction, arriving fresh from
  /// register left `_secondsRemaining` at 0, so the resend link was tappable
  /// immediately on top of the email `registerWithEmailPassword` had just
  /// sent moments earlier — Firebase throttles a same-address resend that
  /// close together *silently*, which is exactly the failure mode D2's
  /// cooldown exists to prevent. The login-403 path must NOT arm it: no
  /// email went out as part of reaching this screen that way, so an
  /// artificial 60s wait before the user can ask for one would be a plain
  /// regression, not caution.
  final bool justSentEmail;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  static const int _resendCooldownSeconds = 60;

  int _secondsRemaining = 0;
  Timer? _resendTimer;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    if (widget.justSentEmail) _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  Future<void> _onResend() async {
    if (_secondsRemaining > 0) return;
    setState(() => _statusMessage = null);
    await ref.read(authViewModelProvider.notifier).resendVerificationEmail();
    if (!mounted) return;
    // Only start the cooldown on success — a failed resend must stay
    // retryable rather than locking the user out for 60s over an error that
    // was never sent.
    if (!ref.read(authViewModelProvider).hasError) _startResendCooldown();
  }

  Future<void> _onCheckStatus() async {
    setState(() => _statusMessage = null);
    final verified = await ref
        .read(authViewModelProvider.notifier)
        .checkEmailVerifiedAndContinue();
    if (!mounted) return;
    if (ref.read(authViewModelProvider).hasError) return;
    if (verified) {
      completeAuthFlow(context);
    } else {
      setState(
        () => _statusMessage = AppStrings.authEmailVerificationNotYetMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final display = authErrorDisplayFor(authState.error);

    return AuthScaffold(
      card: _EmailVerificationCard(
        email: widget.email,
        isLoading: authState.isLoading,
        errorMessage: display?.message,
        errorCode: display?.code,
        // No code check here — `AuthErrorBanner` alone decides whether a
        // code gets a retry button (ADR-0021 D3, code-critic GATE 3 round 1
        // — see the matching comment in `login_screen.dart`).
        onRetry: _onCheckStatus,
        statusMessage: _statusMessage,
        secondsRemaining: _secondsRemaining,
        onCheckStatus: _onCheckStatus,
        onResend: _onResend,
        onBackToLogin: () => context.popOrGoHome(),
      ),
    );
  }
}

class _EmailVerificationCard extends StatelessWidget {
  const _EmailVerificationCard({
    required this.email,
    required this.isLoading,
    required this.errorMessage,
    required this.errorCode,
    required this.onRetry,
    required this.statusMessage,
    required this.secondsRemaining,
    required this.onCheckStatus,
    required this.onResend,
    required this.onBackToLogin,
  });

  final String email;
  final bool isLoading;
  final String? errorMessage;
  final String? errorCode;
  final VoidCallback? onRetry;
  final String? statusMessage;
  final int secondsRemaining;
  final VoidCallback onCheckStatus;
  final VoidCallback onResend;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.glassCardFill,
        border: Border.all(color: AppColors.glassCardBorder),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.authEmailVerificationHeading,
            style: AppTextStyles.authCardHeading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.authEmailVerificationSubtitlePrefix,
            style: AppTextStyles.cardSubtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            email,
            style: AppTextStyles.cardSubtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.authEmailVerificationInstructions,
            style: AppTextStyles.cardSubtitle,
            textAlign: TextAlign.center,
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              statusMessage!,
              style: AppTextStyles.cardSubtitle.copyWith(
                color: AppColors.accent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AuthErrorBanner(
              message: errorMessage!,
              code: errorCode,
              onRetry: onRetry,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AuthPrimaryButton(
            label: AppStrings.authEmailVerificationCheckButton,
            isLoading: isLoading,
            onPressed: isLoading ? null : onCheckStatus,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ResendRow(secondsRemaining: secondsRemaining, onResend: onResend),
          const SizedBox(height: AppSpacing.sm),
          AuthNavLinkRow(
            promptText: AppStrings.authEmailVerificationBackToLoginPrompt,
            actionText: AppStrings.authSubmitLogin,
            onTap: onBackToLogin,
          ),
        ],
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsRemaining, required this.onResend});

  final int secondsRemaining;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (secondsRemaining > 0) {
      return Text(
        '${AppStrings.authEmailVerificationResendCountdownPrefix}'
        '$secondsRemaining'
        '${AppStrings.authEmailVerificationResendCountdownSuffix}',
        style: AppTextStyles.cardSubtitle.copyWith(
          color: AppColors.placeholderGray,
        ),
        textAlign: TextAlign.center,
      );
    }
    return Center(
      child: GestureDetector(
        onTap: onResend,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: AppStrings.authEmailVerificationResendPrompt,
                style: AppTextStyles.cardSubtitle,
              ),
              TextSpan(
                text: AppStrings.authEmailVerificationResendAction,
                style: AppTextStyles.linkBold,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
