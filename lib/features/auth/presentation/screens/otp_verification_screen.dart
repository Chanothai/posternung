import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/router/app_navigation.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/datasources/phone_sign_in_data_source.dart';
import '../auth_error_display.dart';
import '../auth_flow_navigation.dart';
import '../providers/auth_providers.dart';
import '../providers/otp_flow_provider.dart';
import '../widgets/auth_error_banner.dart';

/// OTP verification screen — user enters the 6-digit code Firebase texted to
/// [phoneNumber]. Shares the login screen's visual shell (gradient + glass
/// card + brand header) so the two read as one flow.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({required this.phoneNumber, super.key});

  /// E.164 phone number the code was sent to (e.g. `+66812345678`) — shown
  /// in the subtitle. Display only, and it does not change for the life of a
  /// flow, so it is passed in rather than read back on every use.
  ///
  /// `verificationId` and `resendToken` are deliberately **not** fields here.
  /// They live in `otpFlowProvider` and are read at the moment they are used
  /// (ADR-0018 Amendment 2 A2-D2): resend replaces them, and a second copy
  /// cached in this widget is how the screen ends up verifying a code
  /// against the SMS *before* the one the user is holding.
  final String phoneNumber;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _codeLength = 6;
  static const int _resendCountdownSeconds = 30;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  int _secondsRemaining = _resendCountdownSeconds;
  Timer? _resendTimer;

  /// Guards against the auto-submit listener firing twice for one code —
  /// `_controller`'s listener fires on every keystroke, so without this a
  /// second notification (or a stray one during the clear-on-failure below)
  /// could call [_submit] again while the first attempt is still in flight.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCodeChanged);
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _controller.removeListener(_onCodeChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    // Repaints the digit cells (they read `controller.text` directly, so
    // nothing else schedules a rebuild on keystroke) and, once the code is
    // complete, submits automatically — there is no submit button.
    setState(() {});
    final isComplete = _controller.text.length == _codeLength;
    final alreadyBusy =
        _isSubmitting || ref.read(authViewModelProvider).isLoading;
    if (isComplete && !alreadyBusy) _submit();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = _resendCountdownSeconds);
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
    final result = await ref
        .read(authViewModelProvider.notifier)
        .sendPhoneCode(
          widget.phoneNumber,
          resendToken: ref.read(otpFlowProvider)?.resendToken,
        );
    if (!mounted) return;
    if (result is SmsCodeSent) {
      // Into the provider, not into this State — the flow owns these, and
      // this is the write that makes a resent code verifiable after a
      // `GoRouter.refresh()` (Amendment 2 A2-D2, INF-18 AC-2).
      ref
          .read(otpFlowProvider.notifier)
          .codeResent(
            verificationId: result.verificationId,
            resendToken: result.resendToken,
          );
      _startResendCountdown();
    } else if (result is PhoneAutoVerified) {
      // Rare on resend, but handle it the same way the initial send does:
      // the session is already published, so just leave the flow.
      completeAuthFlow(context);
    }
    // On error, the banner below (driven by the same authState) shows it.
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    // Read at the moment of use, so a resend that happened since this screen
    // was built is what gets verified.
    final String? verificationId = ref.read(otpFlowProvider)?.verificationId;
    if (verificationId == null) {
      // The flow ended underneath us (the user is on their way out). Sending
      // a confirmation now would publish a session for a screen nobody is
      // looking at.
      return;
    }
    _isSubmitting = true;
    final code = _controller.text;
    await ref
        .read(authViewModelProvider.notifier)
        .confirmPhoneCode(verificationId: verificationId, smsCode: code);
    if (!mounted) return;
    if (ref.read(authViewModelProvider).hasError) {
      // Wrong code: clear the input so the user can retype without manually
      // deleting 6 digits first, and re-focus so the keyboard is still up.
      // Clearing fires `_onCodeChanged` (length 0, no re-submit) which also
      // repaints the cells with the new error styling.
      _isSubmitting = false;
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }
    // Pushed on top of the login screen, so — unlike login, which AuthGate
    // swaps out directly — success needs an explicit pop back to root to
    // reveal the destination AuthGate already switched to underneath.
    completeAuthFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final display = authErrorDisplayFor(authState.error);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _BackButton(onPressed: () => context.popOrGoHome()),
                  ),
                  const _BrandHeader(),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: _OtpCard(
                      phoneNumber: widget.phoneNumber,
                      controller: _controller,
                      focusNode: _focusNode,
                      hasError: authState.hasError,
                      isLoading: authState.isLoading,
                      errorMessage: display?.message,
                      errorCode: display?.code,
                      secondsRemaining: _secondsRemaining,
                      onResend: _onResend,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: AppDimens.iconMd,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

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

class _OtpCard extends StatelessWidget {
  const _OtpCard({
    required this.phoneNumber,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.isLoading,
    required this.errorMessage,
    required this.errorCode,
    required this.secondsRemaining,
    required this.onResend,
  });

  final String phoneNumber;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool isLoading;
  final String? errorMessage;
  final String? errorCode;
  final int secondsRemaining;
  final VoidCallback onResend;

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
            AppStrings.authOtpHeading,
            style: AppTextStyles.authCardHeading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.authOtpSubtitlePrefix,
            style: AppTextStyles.cardSubtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            phoneNumber,
            style: AppTextStyles.cardSubtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          _OtpInput(
            controller: controller,
            focusNode: focusNode,
            hasError: hasError,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AuthErrorBanner(message: errorMessage!, code: errorCode),
          ],
          // No submit button — verification fires automatically once all 6
          // digits are entered (see `_onCodeChanged`). This is the only
          // feedback that a request is in flight.
          if (isLoading) ...[
            const SizedBox(height: 20),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _ResendRow(secondsRemaining: secondsRemaining, onResend: onResend),
        ],
      ),
    );
  }
}

/// Six-cell code entry backed by a single [TextEditingController]: a
/// transparent full-width field captures input (so paste, OS SMS autofill,
/// and backspace all work) while a row of visual cells renders each digit.
class _OtpInput extends StatelessWidget {
  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.hasError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;

  static const int _length = 6;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < _length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _OtpCell(
                  digit: i < code.length ? code[i] : '',
                  active: i == code.length && code.length < _length,
                  hasError: hasError,
                ),
              ),
            ],
          ],
        ),
        // Transparent capture field on top. Opacity(0) still hit-tests, so a
        // tap anywhere on the cells focuses it and pops the keyboard.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              showCursor: false,
              enableInteractiveSelection: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_length),
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    if (hasError) {
      borderColor = Colors.redAccent;
    } else if (active) {
      borderColor = AppColors.accent;
    } else {
      borderColor = AppColors.borderMuted;
    }

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: borderColor,
            width: active || hasError ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: AppTextStyles.inputText.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
        '${AppStrings.authOtpResendCountdownPrefix}$secondsRemaining'
        '${AppStrings.authOtpResendCountdownSuffix}',
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
                text: AppStrings.authOtpResendPrompt,
                style: AppTextStyles.cardSubtitle,
              ),
              TextSpan(
                text: AppStrings.authOtpResendAction,
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
