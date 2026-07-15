import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../auth/presentation/auth_gate.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_authenticate_page_content.dart';
import '../widgets/onboarding_first_page_content.dart';
import '../widgets/onboarding_footer.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_limit_stock_page_content.dart';

/// Onboarding flow: 3 swipeable pages ("Own a Piece of Cinema History",
/// "100% Authenticated Originals", "Limited Stock — One of a Kind"),
/// advanceable by swipe or by tapping "Next".
///
/// Figma: nodes 6:2, 7:2, 7:90.
class OnboardingPageViewScreen extends ConsumerStatefulWidget {
  const OnboardingPageViewScreen({super.key});

  @override
  ConsumerState<OnboardingPageViewScreen> createState() =>
      _OnboardingPageViewScreenState();
}

class _OnboardingPageViewScreenState
    extends ConsumerState<OnboardingPageViewScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _enterApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate(builder: _buildHome)),
    );
  }

  static Widget _buildHome(BuildContext context) => const HomeScreen();

  void _onNext(int currentPage) {
    if (currentPage < onboardingPageCount - 1) {
      _pageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _enterApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingControllerProvider);
    final isLastPage = currentPage == onboardingPageCount - 1;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: currentPage,
            children: const [
              AppGradientBackground(),
              AppGradientBackground(),
              AppGradientBackground(),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                OnboardingHeader(onSkip: isLastPage ? null : _enterApp),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => ref
                        .read(onboardingControllerProvider.notifier)
                        .setPage(index),
                    children: const [
                      _OnboardingPageScroll(
                        child: OnboardingFirstPageContent(),
                      ),
                      _OnboardingPageScroll(
                        child: OnboardingAuthenticatePageContent(),
                      ),
                      _OnboardingPageScroll(
                        child: OnboardingLimitStockPageContent(),
                      ),
                    ],
                  ),
                ),
                OnboardingFooter(
                  pageController: _pageController,
                  buttonLabel: isLastPage
                      ? AppStrings.onboardingGetStartedButton
                      : AppStrings.onboardingNextButton,
                  showArrowIcon: !isLastPage,
                  onNext: () => _onNext(currentPage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared scroll/centering wrapper applied to every onboarding page's
/// content, so short content stays centered and tall content scrolls
/// instead of overflowing.
class _OnboardingPageScroll extends StatelessWidget {
  const _OnboardingPageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
