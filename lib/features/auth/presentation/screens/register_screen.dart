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
import '../widgets/auth_email_field.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_nav_link_row.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';

/// Register screen — email/password account creation, split out of
/// [LoginScreen]. Same theme as login, but no Google/Apple buttons: social
/// sign-in already creates an account on first use, so it has no separate
/// "register" step.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await ref
        .read(authViewModelProvider.notifier)
        .signUp(email: email, password: password);

    if (!mounted) return;
    if (!ref.read(authViewModelProvider).hasError) completeAuthFlow(context);
  }

  void _toggleObscurePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final display = authErrorDisplayFor(authState.error);

    return AuthScaffold(
      card: _RegisterCard(
        formKey: _formKey,
        emailController: _emailController,
        passwordController: _passwordController,
        obscurePassword: _obscurePassword,
        onToggleObscure: _toggleObscurePassword,
        isLoading: authState.isLoading,
        errorMessage: display?.message,
        errorCode: display?.code,
        onSubmit: authState.isLoading ? null : _submit,
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.errorMessage,
    required this.errorCode,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final String? errorMessage;
  final String? errorCode;
  final VoidCallback? onSubmit;

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
            Text(
              AppStrings.authHeadingRegister,
              style: AppTextStyles.authCardHeading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.authSubtitleRegister,
              style: AppTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthEmailField(controller: emailController, autofocus: true),
            const SizedBox(height: 20),
            AuthPasswordField(
              controller: passwordController,
              obscure: obscurePassword,
              onToggleObscure: onToggleObscure,
              showForgotPassword: false,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              AuthErrorBanner(message: errorMessage!, code: errorCode),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: AppStrings.authSubmitRegister,
              isLoading: isLoading,
              onPressed: onSubmit,
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthNavLinkRow(
              promptText: AppStrings.authTogglePromptRegister,
              actionText: AppStrings.authSubmitLogin,
              onTap: () => context.popOrGoHome(),
            ),
          ],
        ),
      ),
    );
  }
}
