import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/features/onboarding/presentation/screens/onboarding_authenticate_screen.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_first_screen.dart';

void main() {
  testWidgets('OnboardingFirstScreen renders hero copy and CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingFirstScreen())),
    );

    expect(find.text('Cinevault 2'), findsOneWidget);
    expect(
      find.text('Own a Piece of\nCinema History', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
  });

  testWidgets('tapping Next navigates to the authenticate screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingFirstScreen())),
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingAuthenticateScreen), findsOneWidget);
  });
}
