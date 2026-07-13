import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../auth/auth_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../home/home_page.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/dashed_circle_border.dart';
import '../widgets/onboarding_footer.dart';
import '../widgets/onboarding_header.dart';

/// Second screen of the onboarding flow ("100% Authenticated Originals").
///
/// Figma: node 7:2, frame "Onboarding - Authenticate".
class OnboardingAuthenticateScreen extends ConsumerWidget {
  const OnboardingAuthenticateScreen({super.key});

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
          const _AuthenticateBackground(),
          SafeArea(
            child: Column(
              children: [
                OnboardingHeader(
                  onSkip: () {
                    controller.skip();
                    _enterApp(context);
                  },
                ),
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
                                  const _CenterpieceBadge(),
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
                  onNext: () {
                    controller.next();
                    // TODO: push the real screen 3 once it exists; this is
                    // currently the last built onboarding screen even though
                    // onboardingPageCount anticipates a third page.
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

class _AuthenticateBackground extends StatelessWidget {
  const _AuthenticateBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.surfaceDark),
        Opacity(
          opacity: 0.9,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.9, -0.4),
                end: Alignment(0.9, 0.4),
                stops: [0, 0.5, 1],
                colors: [
                  AppColors.surfaceDark,
                  AppColors.surfaceDark,
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterpieceBadge extends StatelessWidget {
  const _CenterpieceBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 256,
      height: 256,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.2,
            child: SvgPicture.asset(
              'assets/images/header_icon.svg',
              width: 256,
              height: 256,
            ),
          ),
          Container(
            width: 192,
            height: 192,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderMuted, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: DashedCircleBorder(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.6),
                                blurRadius: 7.5,
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/images/verified_badge_icon.svg',
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text('ยืนยันแล้ว', style: AppTextStyles.badgeLabel),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                text: 'รับรองความแท้ 100%\n',
                style: AppTextStyles.heroTitleSmall,
              ),
              TextSpan(
                text: 'ต้นฉบับ',
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
            'โปสเตอร์ทุกชิ้นผ่านการตรวจสอบอย่างเข้มงวดโดยผู้เชี่ยวชาญ '
            'พร้อมใบรับรองความแท้แบบดิจิทัลและการตรวจสอบที่มาโดยละเอียด',
            style: AppTextStyles.bodyDescription,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
