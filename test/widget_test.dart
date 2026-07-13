// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
