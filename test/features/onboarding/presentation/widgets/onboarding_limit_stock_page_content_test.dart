import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/features/onboarding/presentation/widgets/onboarding_limit_stock_page_content.dart';

void main() {
  testWidgets('renders the stock badge and copy', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OnboardingLimitStockPageContent()),
      ),
    );

    expect(find.text('เหลือ 1\nชิ้นสุดท้าย'), findsOneWidget);
    expect(
      find.text('สินค้ามีจำนวนจำกัด\n— ชิ้นเดียวในโลก', findRichText: true),
      findsOneWidget,
    );
  });
}
