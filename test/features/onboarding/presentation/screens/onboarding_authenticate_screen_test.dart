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

    expect(find.text('PosterNung'), findsOneWidget);
    expect(find.text('ข้าม'), findsOneWidget);
    expect(find.text('ยืนยันแล้ว'), findsOneWidget);
    expect(
      find.text('รับรองความแท้ 100%\nต้นฉบับ', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('ถัดไป'), findsOneWidget);
  });
}
