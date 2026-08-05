import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_first_page_content.dart';

void main() {
  testWidgets('renders the hero title and description', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OnboardingFirstPageContent())),
    );

    expect(
      find.text(
        AppStrings.onboardingHeroTitlePage1Prefix +
            AppStrings.onboardingHeroTitlePage1Emphasis,
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.onboardingBodyPage1), findsOneWidget);
  });
}
