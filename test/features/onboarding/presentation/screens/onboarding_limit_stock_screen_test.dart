import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/features/onboarding/presentation/screens/onboarding_limit_stock_screen.dart';

void main() {
  testWidgets(
    'OnboardingLimitStockScreen renders copy and CTA with skip hidden',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: OnboardingLimitStockScreen()),
        ),
      );

      expect(find.text('PosterNung'), findsOneWidget);
      expect(find.text('เหลือ 1\nชิ้นสุดท้าย'), findsOneWidget);
      expect(
        find.text('สินค้ามีจำนวนจำกัด\n— ชิ้นเดียวในโลก', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);

      // Skip exists for layout parity with the other onboarding screens but
      // is hidden/disabled — the last screen has nothing left to skip to.
      final skip = tester.widget<Opacity>(
        find.ancestor(of: find.text('ข้าม'), matching: find.byType(Opacity)),
      );
      expect(skip.opacity, 0);
    },
  );
}
