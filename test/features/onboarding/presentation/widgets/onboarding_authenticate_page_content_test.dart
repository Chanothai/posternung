import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_authenticate_page_content.dart';

void main() {
  testWidgets('renders the badge label and copy', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OnboardingAuthenticatePageContent()),
      ),
    );

    expect(find.text(AppStrings.onboardingVerifiedBadge), findsOneWidget);
    expect(
      find.text(
        AppStrings.onboardingHeroTitlePage2Prefix +
            AppStrings.onboardingHeroTitlePage2Emphasis,
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.onboardingBodyPage2), findsOneWidget);
  });
}
