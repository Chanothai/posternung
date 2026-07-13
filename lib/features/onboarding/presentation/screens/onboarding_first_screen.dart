import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/auth_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../home/home_page.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_footer.dart';
import '../widgets/onboarding_header.dart';
import 'onboarding_authenticate_screen.dart';

/// First screen of the onboarding flow ("Own a Piece of Cinema History").
///
/// Figma: node 6:2, frame "Onboarding - Vintage Hero".
class OnboardingFirstScreen extends ConsumerWidget {
  const OnboardingFirstScreen({super.key});

  void _enterApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate(builder: _buildHome)),
    );
  }

  static Widget _buildHome(BuildContext context) =>
      const MyHomePage(title: 'Cinevault');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _HeroBackground(),
          SafeArea(
            child: Column(
              children: [
                OnboardingHeader(
                  onSkip: () {
                    controller.skip();
                    _enterApp(context);
                  },
                ),
                const Spacer(flex: 3),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: _HeroContent(),
                ),
                const Spacer(flex: 2),
                OnboardingFooter(
                  currentPage: currentPage,
                  onNext: () {
                    controller.next();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingAuthenticateScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  // TODO: swap for the vintage film poster collage once that image fill is
  // generated in Figma — the source frame currently has no image, only a
  // text prompt as the layer name.
  static const Color _baseTop = Color(0xFF6E5A45);
  static const Color _baseBottom = Color(0xFF3A2F27);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_baseTop, _baseBottom],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.5, 1],
              colors: [
                AppColors.surfaceDark.withValues(alpha: 0.8),
                AppColors.surfaceDark.withValues(alpha: 0.4),
                AppColors.surfaceDark,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Own a Piece of\n',
                  style: AppTextStyles.heroTitle,
                ),
                TextSpan(
                  text: 'Cinema History',
                  style: AppTextStyles.heroTitleEmphasis,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Text(
              'Discover and collect rare, authenticated original movie '
              'posters from your favorite eras.',
              style: AppTextStyles.bodyDescription,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
