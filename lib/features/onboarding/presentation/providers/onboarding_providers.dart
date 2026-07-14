import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Total number of steps in the onboarding flow (mirrors the 3 progress
/// dots in the Figma design).
const int onboardingPageCount = 3;

class OnboardingController extends Notifier<int> {
  @override
  int build() => 0;

  void setPage(int index) {
    state = index.clamp(0, onboardingPageCount - 1);
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, int>(OnboardingController.new);
