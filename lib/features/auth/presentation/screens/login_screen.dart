import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/thai_phone_number.dart';
import '../../data/datasources/phone_sign_in_data_source.dart';
import '../auth_error_display.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_email_field.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_nav_link_row.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

/// Which credential the auth card is collecting. Email is the login flow;
/// phone is passwordless — entering a number sends straight to
/// [OtpVerificationScreen]. Register lives on its own screen ([RegisterScreen]),
/// reached via the nav link at the bottom of email mode.
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_method == _AuthMethod.phone) {
      final phoneNumber = thaiMobileToE164(_phoneController.text);
      if (phoneNumber == null) return;
      final result = await ref
          .read(authViewModelProvider.notifier)
          .sendPhoneCode(phoneNumber);
      if (!mounted) return;
      if (result is SmsCodeSent) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: phoneNumber,
              verificationId: result.verificationId,
              resendToken: result.resendToken,
            ),
          ),
        );
      }
      // PhoneAutoVerified: the session is already published — AuthGate
      // reacts on its own since LoginScreen is the root, not a pushed route.
      // Error: already surfaced by the AuthErrorBanner below, which watches
      // the same authState this method also drives.
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await ref
        .read(authViewModelProvider.notifier)
        .signIn(email: email, password: password);
  }

  void _setMethod(_AuthMethod method) => setState(() => _method = method);

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _toggleObscurePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  void _onGooglePressed() {
    if (kIsWeb) return _showMobileOnly();
    ref.read(authViewModelProvider.notifier).signInWithGoogle();
  }

  void _onApplePressed() {
    if (kIsWeb) return _showMobileOnly();
    ref.read(authViewModelProvider.notifier).signInWithApple();
  }

  void _showMobileOnly() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.authMobileOnlyMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    // Sign in with Apple is hidden in the UI until native entitlements are
    // restored (see docs/social-login-setup.md, "iOS Sign in with Apple is
    // currently disabled at the native level"). Flip back to
    // `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS` (Apple
    // sign-in is iOS-only; defaultTargetPlatform is web-safe, unlike
    // dart:io Platform) to re-enable.
    const showAppleButton = false;
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
        errorMessage: errorMessage,
        errorCode: errorCode,
        onSubmit: authState.isLoading ? null : _submit,
        onGoToRegister: _goToRegister,
        onGooglePressed: _onGooglePressed,
        onApplePressed: _onApplePressed,
        showAppleButton: showAppleButton,
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
    required this.onSubmit,
    required this.onGoToRegister,
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.showAppleButton,
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
  final VoidCallback? onSubmit;
  final VoidCallback onGoToRegister;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool showAppleButton;

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
              AuthErrorBanner(message: errorMessage!, code: errorCode),
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
            if (showAppleButton) ...[
              const SizedBox(height: AppSpacing.md),
              _AppleSignInButton(onPressed: onApplePressed),
            ],
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

class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          side: const BorderSide(color: Color(0xFF27272A)),
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppImages.appleLogo, width: 15, height: 20),
            const SizedBox(width: AppSpacing.md),
            Text(
              AppStrings.authAppleSignIn,
              style: AppTextStyles.cardSubtitle.copyWith(
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
