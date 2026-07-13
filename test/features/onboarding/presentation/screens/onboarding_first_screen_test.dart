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

    expect(find.text('PosterNung'), findsOneWidget);
    expect(
      find.text(
        'เป็นเจ้าของชิ้นส่วนหนึ่งของ\nประวัติศาสตร์ภาพยนตร์',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.text('ข้าม'), findsOneWidget);
  });

  testWidgets('tapping Next navigates to the authenticate screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingFirstScreen())),
    );

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingAuthenticateScreen), findsOneWidget);
  });
}
