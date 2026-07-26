import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/datasources/phone_sign_in_data_source.dart';
import '../auth_error_display.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_primary_button.dart';

/// OTP verification screen — user enters the 6-digit code Firebase texted to
/// [phoneNumber]. Shares the login screen's visual shell (gradient + glass
/// card + brand header) so the two read as one flow.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    super.key,
  });

  /// E.164 phone number the code was sent to (e.g. `+66812345678`) — shown
  /// in the subtitle and reused if the user taps resend.
  final String phoneNumber;

  /// Firebase's verification ID for the code currently in flight. Replaced
  /// locally on resend.
  final String verificationId;

  /// The `forceResendingToken` from the send that brought the user here.
  /// Required for resend to actually trigger a second SMS — Firebase sends
  /// nothing without it. Replaced locally on each successful resend.
  final int? resendToken;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _codeLength = 6;
  static const int _resendCountdownSeconds = 30;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late String _verificationId = widget.verificationId;
  late int? _resendToken = widget.resendToken;
  bool _showIncompleteError = false;
  int _secondsRemaining = _resendCountdownSeconds;
  Timer? _resendTimer;

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
    setState(() {
      // Clear the "incomplete" hint as soon as the user resumes typing.
      if (_showIncompleteError) _showIncompleteError = false;
    });
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
        .sendPhoneCode(widget.phoneNumber, resendToken: _resendToken);
    if (!mounted) return;
    if (result is SmsCodeSent) {
      setState(() {
        _verificationId = result.verificationId;
        _resendToken = result.resendToken;
      });
      _startResendCountdown();
    } else if (result is PhoneAutoVerified) {
      // Rare on resend, but handle it the same way the initial send does:
      // the session is already published, so just leave the flow.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    // On error, the banner below (driven by the same authState) shows it.
  }

  Future<void> _submit() async {
    final code = _controller.text;
    if (code.length < _codeLength) {
      setState(() => _showIncompleteError = true);
      _focusNode.requestFocus();
      return;
    }
    await ref
        .read(authViewModelProvider.notifier)
        .confirmPhoneCode(verificationId: _verificationId, smsCode: code);
    if (!mounted) return;
    if (!ref.read(authViewModelProvider).hasError) {
      // Pushed on top of the login screen, so — unlike login, which
      // AuthGate swaps out directly — success needs an explicit pop back to
      // root to reveal the destination AuthGate already switched to
      // underneath. Same pattern as RegisterScreen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final error = authState.error;
    final String? errorMessage;
    final String? errorCode;
    if (error is AuthException) {
      final display = authErrorDisplay(error);
      errorMessage = display.message;
      errorCode = display.code;
    } else if (error != null) {
      errorMessage = AppStrings.authErrorGeneric;
      errorCode = null;
    } else {
      errorMessage = null;
      errorCode = null;
    }

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
                    child: _BackButton(
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                  const _BrandHeader(),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: _OtpCard(
                      phoneNumber: widget.phoneNumber,
                      controller: _controller,
                      focusNode: _focusNode,
                      showIncompleteError: _showIncompleteError,
                      isLoading: authState.isLoading,
                      errorMessage: errorMessage,
                      errorCode: errorCode,
                      onSubmit: authState.isLoading ? null : _submit,
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
    required this.showIncompleteError,
    required this.isLoading,
    required this.errorMessage,
    required this.errorCode,
    required this.onSubmit,
    required this.secondsRemaining,
    required this.onResend,
  });

  final String phoneNumber;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showIncompleteError;
  final bool isLoading;
  final String? errorMessage;
  final String? errorCode;
  final VoidCallback? onSubmit;
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
            hasError: showIncompleteError,
          ),
          if (showIncompleteError) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.authOtpIncompleteError,
              style: AppTextStyles.cardSubtitle.copyWith(
                color: Colors.redAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AuthErrorBanner(message: errorMessage!, code: errorCode),
          ],
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: AppStrings.authOtpSubmit,
            isLoading: isLoading,
            onPressed: onSubmit,
          ),
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
