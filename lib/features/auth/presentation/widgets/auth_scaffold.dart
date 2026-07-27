import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_background.dart';
import 'auth_brand_header.dart';

/// Shared visual shell for auth screens (login, register): gradient
/// background, brand header, and a width-constrained scrollable slot for
/// the screen's own card content.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.card, super.key});

  final Widget card;

  @override
  Widget build(BuildContext context) {
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
                  const AuthBrandHeader(),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: card,
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
