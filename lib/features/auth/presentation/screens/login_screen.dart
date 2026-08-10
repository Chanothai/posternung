import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/thai_phone_number.dart';
import '../../data/datasources/phone_sign_in_data_source.dart';
import '../auth_error_display.dart';
import '../auth_flow_navigation.dart';
import '../providers/email_verification_flow_provider.dart';
import '../providers/otp_flow_provider.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_email_field.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_nav_link_row.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';

/// Which credential the auth card is collecting. Email is the login flow;
/// phone is passwordless — entering a number sends straight to
/// `AppRoutes.otpPath`. Register lives on its own screen
/// (`AppRoutes.registerPath`), reached via the nav link at the bottom of
/// email mode.
enum _AuthMethod { email, phone }

/// Login screen — email/phone method tabs, matching the old `LoginPage`'s
/// behavior under the new design.
///
/// Figma: node 7:130, frame "Login/Register" (phone tab has no Figma spec —
/// built to match the existing theme).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  _AuthMethod _method = _AuthMethod.email;
  bool _obscurePassword = true;

  /// Whichever submit action last ran — retried by the error banner's retry
  /// button, which only ever appears for `OAUTH_LOGIN_CONFLICT` (ADR-0021
  /// D3). Both `_submit` and `_onGooglePressed` can produce that code (both
  /// end at the same `/auth/firebase` exchange), so the banner has to be
  /// able to retry whichever one actually ran, not always the same one.
  VoidCallback? _lastAction;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (_method == _AuthMethod.phone) {
      // 🔴 Deliberately does NOT set `_lastAction = _submit` here (code-critic
      // GATE 3 round 1). A 409 on this branch can only come from
      // `PhoneAutoVerified`'s internal exchange (`sendPhoneCode`'s
      // `SmsCodeSent` path never exchanges at all — that happens later, on
      // `OtpVerificationScreen`) — by the time that error surfaces, the
      // Firebase phone-verification attempt that produced it is already
      // spent. Retrying via `_submit()` would start an entirely new
      // `sendCode(phoneNumber)` call with no `resendToken`, which is not
      // "retry the failed exchange" — it is "start a new verification
      // attempt", and Firebase's own de-dup/throttling on repeated initial
      // sends for the same number can silently do nothing. Leaving
      // `_lastAction` unset here means no retry button shows for this
      // sub-case (the banner still shows the error+code) rather than
      // wiring one that fires the wrong action. Clearing it (not just
      // skipping the assignment) also stops a *stale* action from an
      // earlier email/Google attempt on this same screen from leaking into
      // a retry button shown for a phone-branch error.
      _lastAction = null;
      final phoneNumber = thaiMobileToE164(_phoneController.text);
      if (phoneNumber == null) return;
      final result = await ref
          .read(authViewModelProvider.notifier)
          .sendPhoneCode(phoneNumber);
      if (!mounted) return;
      if (result is SmsCodeSent) {
        // The flow's state goes to the state layer, not to the route
        // (ADR-0018 Amendment 2 A2-D2) — `OtpFlowState` documents why, and
        // `start` deliberately replaces any leftover from an earlier flow
        // wholesale rather than merging into it.
        ref
            .read(otpFlowProvider.notifier)
            .start(
              OtpFlowState(
                phoneNumber: phoneNumber,
                verificationId: result.verificationId,
                resendToken: result.resendToken,
              ),
            );
        // `push`, so back from OTP returns here rather than replacing this
        // screen. Nothing rides along: the route carries no arguments, so
        // none of these values can reach a path or query string (D6).
        await context.push(AppRoutes.otpPath);
        // Back from OTP without having completed it (or after a failed
        // attempt there) must not leave that screen's error banner showing
        // here — both screens watch the same authViewModelProvider.
        if (!mounted) return;
        ref.read(authViewModelProvider.notifier).clearError();
        return;
      }
      if (result is PhoneAutoVerified) {
        // The session is already published, so `AuthGate` swaps to the
        // destination by itself. `completeAuthFlow` still runs: this screen
        // is `AuthGate`'s child at `AppRoutes.homePath` with nothing stacked
        // above it, so the `go` inside resolves to the location we are
        // already on and moves nothing — but it owns the unfocus, and
        // sending every success through the one call is what stops each
        // screen from having to know how deep it happens to be.
        completeAuthFlow(context);
      }
      // Error: already surfaced by the AuthErrorBanner below, which watches
      // the same authState this method also drives.
      return;
    }

    // Safe to retry via `_submit()` from scratch on any failure here — unlike
    // the phone branch above, nothing about this call consumes state that a
    // second attempt would need (see the comment on that branch).
    _lastAction = _submit;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await ref
        .read(authViewModelProvider.notifier)
        .signIn(email: email, password: password);
    if (!mounted) return;

    // ADR-0021 D2, row 2: a `password`-provider login answering
    // 403 OAUTH_EMAIL_NOT_VERIFIED is a route, not an error — this user
    // typed the right password, what's missing is a step, not a
    // permission. 🔴 Deliberately keyed off *this call site* (the
    // email/password submit), not off the error code in isolation: the same
    // code from a `google.com` exchange (theoretically possible, never
    // expected — Google verifies email itself) falls through to the normal
    // error banner below instead.
    final error = ref.read(authViewModelProvider).error;
    if (error is AuthException && error.code == oauthEmailNotVerifiedCode) {
      ref.read(authViewModelProvider.notifier).clearError();
      ref
          .read(emailVerificationFlowProvider.notifier)
          .start(
            EmailVerificationFlowState(email: email, justSentEmail: false),
          );
      await context.push(AppRoutes.emailVerificationPath);
      // Same reasoning as the OTP push above: back from verification without
      // completing it must not leave this screen showing a stale error.
      if (!mounted) return;
      ref.read(authViewModelProvider.notifier).clearError();
      return;
    }

    if (!ref.read(authViewModelProvider).hasError) completeAuthFlow(context);
  }

  void _setMethod(_AuthMethod method) => setState(() => _method = method);

  /// `push`, not `go` — the register screen's "already have an account?" link
  /// and the system back gesture both have to come back here.
  void _goToRegister() => context.push(AppRoutes.registerPath);

  void _toggleObscurePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  Future<void> _onGooglePressed() async {
    if (kIsWeb) return _showMobileOnly();
    FocusScope.of(context).unfocus();
    _lastAction = _onGooglePressed;
    await ref.read(authViewModelProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (!ref.read(authViewModelProvider).hasError) completeAuthFlow(context);
  }

  void _showMobileOnly() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.authMobileOnlyMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final display = authErrorDisplayFor(authState.error);

    return AuthScaffold(
      card: _AuthCard(
        formKey: _formKey,
        method: _method,
        onMethodChanged: _setMethod,
        emailController: _emailController,
        passwordController: _passwordController,
        phoneController: _phoneController,
        obscurePassword: _obscurePassword,
        onToggleObscure: _toggleObscurePassword,
        isLoading: authState.isLoading,
        errorMessage: display?.message,
        errorCode: display?.code,
        // No code check here — `AuthErrorBanner` is the one place that
        // decides whether a code gets a retry button at all (ADR-0021 D3,
        // code-critic GATE 3 round 1: the same `code ==
        // oauthLoginConflictCode` check used to be duplicated at every call
        // site *and* inside the banner, so disarming any one of them alone
        // never made a test fail). This screen only ever supplies *which*
        // action retry should run.
        onRetry: _lastAction,
        onSubmit: authState.isLoading ? null : _submit,
        onGoToRegister: _goToRegister,
        onGooglePressed: _onGooglePressed,
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formKey,
    required this.method,
    required this.onMethodChanged,
    required this.emailController,
    required this.passwordController,
    required this.phoneController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.errorMessage,
    required this.errorCode,
    required this.onRetry,
    required this.onSubmit,
    required this.onGoToRegister,
    required this.onGooglePressed,
  });

  final GlobalKey<FormState> formKey;
  final _AuthMethod method;
  final ValueChanged<_AuthMethod> onMethodChanged;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController phoneController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final String? errorMessage;
  final String? errorCode;
  final VoidCallback? onRetry;
  final VoidCallback? onSubmit;
  final VoidCallback onGoToRegister;
  final VoidCallback onGooglePressed;

  @override
  Widget build(BuildContext context) {
    final isPhone = method == _AuthMethod.phone;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.glassCardFill,
        border: Border.all(color: AppColors.glassCardBorder),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MethodTabs(method: method, onChanged: onMethodChanged),
            const SizedBox(height: AppSpacing.xl),
            _HeadingBlock(method: method),
            const SizedBox(height: AppSpacing.xl),
            if (isPhone)
              _PhoneField(controller: phoneController)
            else ...[
              AuthEmailField(controller: emailController, autofocus: true),
              const SizedBox(height: 20),
              AuthPasswordField(
                controller: passwordController,
                obscure: obscurePassword,
                onToggleObscure: onToggleObscure,
                showForgotPassword: true,
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
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: isPhone
                  ? AppStrings.authSubmitPhoneOtp
                  : AppStrings.authSubmitLogin,
              isLoading: isLoading,
              onPressed: onSubmit,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _OrDivider(),
            const SizedBox(height: AppSpacing.xl),
            _GoogleSignInButton(onPressed: onGooglePressed),
            if (!isPhone) ...[
              const SizedBox(height: AppSpacing.sm),
              AuthNavLinkRow(
                promptText: AppStrings.authTogglePromptLogin,
                actionText: AppStrings.authHeadingRegister,
                onTap: onGoToRegister,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodTabs extends StatelessWidget {
  const _MethodTabs({required this.method, required this.onChanged});

  final _AuthMethod method;
  final ValueChanged<_AuthMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MethodTab(
            label: AppStrings.authMethodEmailTab,
            selected: method == _AuthMethod.email,
            onTap: () => onChanged(_AuthMethod.email),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MethodTab(
            label: AppStrings.authMethodPhoneTab,
            selected: method == _AuthMethod.phone,
            onTap: () => onChanged(_AuthMethod.phone),
          ),
        ),
      ],
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderMuted,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.inputLabel.copyWith(
            color: selected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _HeadingBlock extends StatelessWidget {
  const _HeadingBlock({required this.method});

  final _AuthMethod method;

  @override
  Widget build(BuildContext context) {
    final heading = method == _AuthMethod.phone
        ? AppStrings.authPhoneHeading
        : AppStrings.authHeadingLogin;
    final subtitle = method == _AuthMethod.phone
        ? AppStrings.authPhoneSubtitle
        : AppStrings.authSubtitleLogin;
    return Column(
      children: [
        Text(
          heading,
          style: AppTextStyles.authCardHeading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: AppTextStyles.cardSubtitle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            AppStrings.authPhoneLabel,
            style: AppTextStyles.inputLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          style: AppTextStyles.inputText,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            // 10, not 9: people habitually type the leading 0
            // (`0812345678`) even though the `+66 ` prefix already implies
            // it — thaiMobileToE164 strips it before dialing.
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            hintText: AppStrings.authPhoneHint,
            hintStyle: AppTextStyles.inputText.copyWith(
              color: AppColors.placeholderGray,
            ),
            // No phone icon in AppImages — a fixed dial-code prefix reads
            // clearly on its own and avoids adding a new asset for this.
            prefixText: '+66 ',
            prefixStyle: AppTextStyles.inputText.copyWith(
              color: AppColors.placeholderGray,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: const BorderSide(color: AppColors.borderMuted),
            ),
          ),
          validator: (value) {
            if (value == null || thaiMobileToE164(value) == null) {
              return AppStrings.authPhoneValidationError;
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.borderMuted, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            AppStrings.authOrDivider,
            style: AppTextStyles.dividerLabel,
          ),
        ),
        const Expanded(child: Divider(color: AppColors.borderMuted, height: 1)),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderMuted),
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppImages.googleLogo, width: 17.16, height: 18),
            const SizedBox(width: AppSpacing.md),
            Text(
              AppStrings.authGoogleSignIn,
              style: AppTextStyles.cardSubtitle.copyWith(
                color: AppColors.surfaceDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
