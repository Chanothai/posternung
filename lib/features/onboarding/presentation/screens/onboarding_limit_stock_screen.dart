import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../auth/auth_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../home/home_page.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_footer.dart';
import '../widgets/onboarding_gradient_background.dart';
import '../widgets/onboarding_header.dart';

/// Third and final screen of the onboarding flow ("Limited Stock — One of a
/// Kind"). Its skip action is hidden — there's nothing left to skip to.
///
/// Figma: node 7:90, frame "Onboarding - limit stock".
class OnboardingLimitStockScreen extends ConsumerWidget {
  const OnboardingLimitStockScreen({super.key});

  void _enterApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate(builder: _buildHome)),
    );
  }

  static Widget _buildHome(BuildContext context) =>
      const MyHomePage(title: 'PosterNung');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const OnboardingGradientBackground(),
          SafeArea(
            child: Column(
              children: [
                const OnboardingHeader(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _CenterpieceIllustration(),
                                  const SizedBox(height: 40),
                                  const _CopyBlock(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                OnboardingFooter(
                  currentPage: currentPage,
                  buttonLabel: 'เริ่มต้นใช้งาน',
                  showArrowIcon: false,
                  onNext: () {
                    controller.next();
                    _enterApp(context);
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

class _CenterpieceIllustration extends StatelessWidget {
  const _CenterpieceIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 192,
      height: 203,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: Transform.rotate(
              angle: -15 * math.pi / 180,
              child: const _FadedPosterCard(),
            ),
          ),
          Positioned(
            right: 0,
            child: Transform.rotate(
              angle: 15 * math.pi / 180,
              child: const _FadedPosterCard(),
            ),
          ),
          const _HighlightedPosterCard(),
        ],
      ),
    );
  }
}

class _FadedPosterCard extends StatelessWidget {
  const _FadedPosterCard();

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
      child: Opacity(
        opacity: 0.3,
        child: Container(
          width: 128,
          height: 176,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderMuted),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _HighlightedPosterCard extends StatelessWidget {
  const _HighlightedPosterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 192,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(58, 51, 44, 0.3),
            offset: Offset(2, 3),
            blurRadius: 2.5,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.4),
          border: Border.all(color: AppColors.borderMuted, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/poster_placeholder_icon.svg',
                width: 30,
                height: 30,
              ),
              const SizedBox(height: 12),
              Text(
                'เหลือ 1\nชิ้นสุดท้าย',
                style: AppTextStyles.stockBadgeLabel,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyBlock extends StatelessWidget {
  const _CopyBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'สินค้ามีจำนวนจำกัด\n',
                style: AppTextStyles.heroTitleSmall,
              ),
              TextSpan(
                text: '— ชิ้นเดียวในโลก',
                style: AppTextStyles.heroTitleSmallEmphasis,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Text(
            'ของหายากหมดเร็วมาก เมื่อโปสเตอร์ชิ้นพิเศษถูกขายไปแล้ว '
            'มันจะหายไปจากคลังตลอดกาล',
            style: AppTextStyles.bodyDescription,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
