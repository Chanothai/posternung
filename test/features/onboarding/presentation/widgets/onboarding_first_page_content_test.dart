import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        'เป็นเจ้าของชิ้นส่วนหนึ่งของ\nประวัติศาสตร์ภาพยนตร์',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'ค้นพบและสะสมโปสเตอร์ภาพยนตร์ต้นฉบับหายากที่ผ่านการรับรอง '
        'จากยุคที่คุณชื่นชอบ',
      ),
      findsOneWidget,
    );
  });
}
