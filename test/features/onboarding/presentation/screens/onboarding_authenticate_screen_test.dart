import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/features/onboarding/presentation/screens/onboarding_authenticate_screen.dart';

void main() {
  testWidgets('OnboardingAuthenticateScreen renders badge copy and CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingAuthenticateScreen()),
      ),
    );

    expect(find.text('Cinevault 2'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(
      find.text('100% Authenticated\nOriginals', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Next'), findsOneWidget);
  });
}
