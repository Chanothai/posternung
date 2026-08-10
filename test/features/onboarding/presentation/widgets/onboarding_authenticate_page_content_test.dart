import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/core/assets/app_images.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_authenticate_page_content.dart';

Future<void> _pumpPage(WidgetTester tester) {
  return tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: OnboardingAuthenticatePageContent()),
    ),
  );
}

void main() {
  testWidgets('renders the page copy', (WidgetTester tester) async {
    await _pumpPage(tester);

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

  // ADR-0014 D1 — ตราคำว่า "ยืนยันแล้ว" ใต้ไอคอนถูกถอดออกแล้ว ห้ามกลับมา
  // เหตุผลเต็มอยู่ใน ADR และใน `lib/features/onboarding/CLAUDE.md` — ไม่เขียนซ้ำที่นี่
  //
  // ไอคอนอยู่ต่อโดยตั้งใจ: ลำพังตัวมันคือเครื่องหมายคำถามในวงประ ไม่ใช่ตรารับรอง
  testWidgets('ไม่มีข้อความใต้ไอคอนกลางหน้าแล้ว แต่ไอคอนยังอยู่ (ADR-0014 D1)', (
    WidgetTester tester,
  ) async {
    await _pumpPage(tester);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader is SvgAssetLoader &&
            (widget.bytesLoader as SvgAssetLoader).assetName ==
                AppImages.questionMarkDashedCircleIcon,
      ),
      findsOneWidget,
      reason: 'ไอคอนกลางวงประหายไป — มติผู้ใช้คือถอดแค่ข้อความ ไม่ถอดไอคอน',
    );

    // เทียบกับ *ทุก* บรรทัดที่เรนเดอร์จริง ไม่ใช่ find.text() ตัวเดียว
    // เพราะ label อาจกลับมาในรูป Text.rich หรือถ้อยคำใกล้เคียงก็ได้
    final rendered = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText());
    expect(
      rendered.where((line) => line.contains('ยืนยัน')),
      isEmpty,
      reason:
          'ตรา "ยืนยันแล้ว" กลับมาขึ้นใต้ไอคอนอีกแล้ว — ADR-0014 D1 ห้ามตราที่สื่อว่า\n'
          'ผ่านการรับรอง · ถ้าดีไซน์ยังมีอยู่ ให้ยึด ADR ไม่ใช่ยึดดีไซน์',
    );
  });
}
