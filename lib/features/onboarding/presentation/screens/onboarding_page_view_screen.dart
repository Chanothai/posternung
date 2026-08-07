import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_authenticate_page_content.dart';
import '../widgets/onboarding_first_page_content.dart';
import '../widgets/onboarding_footer.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_limit_stock_page_content.dart';

/// Onboarding flow: 3 swipeable pages — own a piece of cinema history, inspect
/// a poster in full before deciding, stock is one of a kind — advanceable by
/// swipe or by tapping "Next".
///
/// Figma: nodes 6:2, 7:2, 7:90. Page 2 no longer matches the frame's title
/// ("100% Authenticated Originals"): ADR-0014 D1 bans claiming the goods are
/// certified authentic, so the page now describes what the app lets a buyer
/// see. Copy lives in `AppStrings`; the Figma frames are stale on this point.
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

  /// `go`, not `push` — onboarding is finished, so it must not stay on the
  /// stack for a back gesture to return to. That is what the
  /// `pushReplacement` this replaced did too. What is behind
  /// [AppRoutes.homePath] (still `AuthGate`, unchanged) is the route table's
  /// business, not this screen's.
  void _enterApp() => context.go(AppRoutes.homePath);

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
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xl,
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
