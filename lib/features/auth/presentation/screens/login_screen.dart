import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../providers/auth_providers.dart';

/// Login/Register screen — a single form, mode-toggled between the two,
/// matching the old `LoginPage`'s behavior under the new design.
///
/// Figma: node 7:130, frame "Login/Register".
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(authViewModelProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegistering) {
      await viewModel.signUp(email: email, password: password);
    } else {
      await viewModel.signIn(email: email, password: password);
    }
  }

  void _toggleMode() => setState(() => _isRegistering = !_isRegistering);

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
    final errorMessage = error is AuthException
        ? error.message
        : error?.toString();

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
                  const _BrandHeader(),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: _AuthCard(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      isRegistering: _isRegistering,
                      obscurePassword: _obscurePassword,
                      onToggleObscure: _toggleObscurePassword,
                      isLoading: authState.isLoading,
                      errorMessage: errorMessage,
                      onSubmit: authState.isLoading ? null : _submit,
                      onToggleMode: _toggleMode,
                      onGooglePressed: _onGooglePressed,
                      onApplePressed: _onApplePressed,
                      showAppleButton: showAppleButton,
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
            'assets/images/header_icon.svg',
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

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isRegistering,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.showAppleButton,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isRegistering;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool showAppleButton;

  @override
  Widget build(BuildContext context) {
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
            _HeadingBlock(isRegistering: isRegistering),
            const SizedBox(height: AppSpacing.xl),
            _EmailField(controller: emailController),
            const SizedBox(height: 20),
            _PasswordField(
              controller: passwordController,
              obscure: obscurePassword,
              onToggleObscure: onToggleObscure,
              showForgotPassword: !isRegistering,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: 20),
            _SubmitButton(
              isLoading: isLoading,
              isRegistering: isRegistering,
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
            const SizedBox(height: AppSpacing.sm),
            _ModeToggleRow(
              isRegistering: isRegistering,
              onToggle: onToggleMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadingBlock extends StatelessWidget {
  const _HeadingBlock({required this.isRegistering});

  final bool isRegistering;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isRegistering
              ? AppStrings.authHeadingRegister
              : AppStrings.authHeadingLogin,
          style: AppTextStyles.authCardHeading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isRegistering
              ? AppStrings.authSubtitleRegister
              : AppStrings.authSubtitleLogin,
          style: AppTextStyles.cardSubtitle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            AppStrings.authEmailLabel,
            style: AppTextStyles.inputLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
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
                'assets/images/email_icon.svg',
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
    required this.showForgotPassword,
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
                'assets/images/lock_icon.svg',
                width: 14,
                height: 16,
              ),
            ),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: obscure
                  ? SvgPicture.asset(
                      'assets/images/eye_icon.svg',
                      width: 20,
                      height: 16,
                    )
                  : const Icon(
                      Icons.visibility,
                      color: AppColors.placeholderGray,
                    ),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.cardSubtitle.copyWith(color: Colors.redAccent),
      textAlign: TextAlign.center,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isLoading,
    required this.isRegistering,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isRegistering;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRegistering
                        ? AppStrings.authSubmitRegister
                        : AppStrings.authSubmitLogin,
                    style: AppTextStyles.authButtonLabel,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SvgPicture.asset(
                    'assets/images/arrow_right.svg',
                    width: AppDimens.iconSm,
                    height: AppDimens.iconSm,
                  ),
                ],
              ),
      ),
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
            SvgPicture.asset(
              'assets/images/google_logo.svg',
              width: 17.16,
              height: 18,
            ),
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
            SvgPicture.asset(
              'assets/images/apple_logo.svg',
              width: 15,
              height: 20,
            ),
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

class _ModeToggleRow extends StatelessWidget {
  const _ModeToggleRow({required this.isRegistering, required this.onToggle});

  final bool isRegistering;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onToggle,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: isRegistering
                    ? AppStrings.authTogglePromptRegister
                    : AppStrings.authTogglePromptLogin,
                style: AppTextStyles.cardSubtitle,
              ),
              TextSpan(
                text: isRegistering
                    ? AppStrings.authSubmitLogin
                    : AppStrings.authHeadingRegister,
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
