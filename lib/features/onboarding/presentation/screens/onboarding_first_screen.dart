import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../auth/auth_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../home/home_page.dart';
import '../providers/onboarding_providers.dart';

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
                _Header(
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
                _Footer(
                  currentPage: currentPage,
                  onNext: () {
                    if (currentPage == onboardingPageCount - 1) {
                      _enterApp(context);
                    } else {
                      controller.next();
                    }
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

class _Header extends StatelessWidget {
  const _Header({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/header_icon.svg',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 8),
              Text('Cinevault 2', style: AppTextStyles.appBarTitle),
            ],
          ),
          InkWell(
            onTap: onSkip,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('SKIP', style: AppTextStyles.skipButton),
            ),
          ),
        ],
      ),
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

class _Footer extends StatelessWidget {
  const _Footer({required this.currentPage, required this.onNext});

  final int currentPage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceDark.withValues(alpha: 0),
            AppColors.surfaceDark,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressIndicator(currentPage: currentPage),
            const SizedBox(height: 32),
            _NextButton(onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(onboardingPageCount, (index) {
        final isActive = index == currentPage;
        return Padding(
          padding: EdgeInsets.only(
            right: index == onboardingPageCount - 1 ? 0 : 12,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent
                  : AppColors.textSecondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        );
      }),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Next', style: AppTextStyles.primaryButton),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/images/arrow_right.svg',
                width: 12.25,
                height: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
