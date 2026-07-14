import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/features/onboarding/presentation/widgets/onboarding_authenticate_page_content.dart';

void main() {
  testWidgets('renders the badge label and copy', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OnboardingAuthenticatePageContent()),
      ),
    );

    expect(find.text('ยืนยันแล้ว'), findsOneWidget);
    expect(
      find.text('รับรองความแท้ 100%\nต้นฉบับ', findRichText: true),
      findsOneWidget,
    );
  });
}
