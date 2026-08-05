// ด่านเชิงลบของ onboarding — ข้อความรับรองความแท้ต้องไม่กลับมาขึ้นจออีก
//
// กฎเต็มอยู่ที่ ADR-0014 D1 (`../workspace/docs/adr/ADR-0014-verification-evidence-model.md`)
// ที่นี่ไม่เขียนกฎซ้ำ — เก็บแค่ตัวบังคับ
//
// ทำไมต้องเป็นเทส ไม่ใช่แค่ให้ `code-critic` ดู: critic ตรวจตอนรีวิว ส่วนเทสรันทุกครั้งใน CI
// · `project-gotchas` §3 บันทึกไว้เองว่า "กฎที่บอกว่าต้องไม่แสดง ต้องมี assertion เชิงลบเสมอ"
//
// 🔴 เทสนี้อ่านข้อความจาก `AppStrings` และจาก widget tree จริง ไม่ได้พิมพ์ copy ที่คาดหวัง
// ลงในเทส — copy ที่พิมพ์ในเทสจะไม่มีวันจับ copy ตัวใหม่ที่มีคนเพิ่มเข้ามาทีหลังได้
// (`project-gotchas` §3 "assertion เชิงลบที่เขียนด้วยภาษาของดีไซน์ = โมฆะโดยโครงสร้าง")

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_page_view_screen.dart';

/// คำที่ ADR-0014 D1 ห้ามใช้อ้างต่อผู้ซื้อ
///
/// ไทยสามตัวแรกคือถ้อยคำที่ onboarding เคยใช้จริงจนถึง 2026-08-05
/// ส่วนภาษาอังกฤษมาจาก D9 ข้อ 7 — ดีไซน์ต้นทาง (uxpilot) ยังเขียนไว้อยู่
/// จึงกันไว้ก่อนที่จะมีคนหยิบกลับมาใส่
///
/// `ยืนยันแล้ว` คือ label ใต้ไอคอนกลางหน้า 2 ที่ถูกถอดออกเมื่อ 2026-08-05
/// (เดิมคือ `AppStrings.onboardingVerifiedBadge` — ลบทิ้งแล้ว) · อยู่ในลิสต์นี้เพราะ
/// ตราคำว่า "ยืนยันแล้ว" ใต้ไอคอนวงกลมคือรูปแบบไทยของ "Verified Original" ตรง ๆ
/// ที่ D1 ห้าม · ต้องเขียนเป็น literal เพราะค่าคงที่ไม่มีอยู่แล้ว — ข้อยกเว้นที่ยอมได้
/// ของกฎ "ห้ามพิมพ์ copy ลงเทส" ด้านบน เพราะนี่คือการตรึง *ถ้อยคำที่ถูกถอดไปแล้ว*
/// ไม่ให้กลับมา ไม่ใช่การทายว่า copy ปัจจุบันเขียนว่าอะไร
/// 🔴 **คัดคำจาก ADR-0014 D9 ข้อ 7 บรรทัดต่อบรรทัด ห้ามคัดจากความจำ** — รอบแรกของ
/// ลิสต์นี้ขาดคำว่า `ของแท้` ซึ่งเป็น *คำแรก* ของ D9 ข้อ 7 และเป็นคำที่ภาษาไทยจะใช้
/// ก่อนเพื่อน · `code-critic` พิสูจน์ว่าด่านรั่วด้วยการเปลี่ยน copy เป็น
/// "โปสเตอร์ของแท้ทุกชิ้น ผ่านการตรวจพิสูจน์แล้ว" แล้วเทสทั้งสองตัว **เขียว**
/// (2026-08-05) · เพิ่มคำใหม่เมื่อไหร่ ให้ไล่จากตัว ADR ไม่ใช่จากที่จำได้
const _bannedClaims = <String>[
  // — D9 ข้อ 7 ห้าคำตามลำดับในไฟล์ —
  'ของแท้',
  'รับรอง',
  'Verified Original',
  'Guaranteed Authentic',
  'Certificate of Authenticity',
  // — D1 §สิ่งที่ห้ามอ้างในทุกช่องทาง —
  'ความแท้',
  'ผู้เชี่ยวชาญ',
  'certified',
  // — ถ้อยคำที่เคยอยู่บนจอจริงแล้วถูกถอด (ตรึงไม่ให้กลับมา) —
  'ยืนยันแล้ว',
];

/// ข้อความ onboarding ทุกตัวที่มีอยู่ใน `AppStrings` วันนี้
///
/// เพิ่มค่าคงที่ `onboarding*` ตัวใหม่เมื่อไหร่ ต้องเพิ่มที่นี่ด้วย — Dart ไม่มี reflection
/// ให้ไล่สมาชิกของคลาสเอง จึงต้องประกาศเอง แต่ยังดีกว่าพิมพ์ตัว copy ลงในเทส
/// เพราะข้อความเปลี่ยนได้โดยเทสไม่ต้องแก้ตาม
const _onboardingCopy = <String>[
  AppStrings.onboardingSkipButton,
  AppStrings.onboardingHeroTitlePage1Prefix,
  AppStrings.onboardingHeroTitlePage1Emphasis,
  AppStrings.onboardingBodyPage1,
  AppStrings.onboardingHeroTitlePage2Prefix,
  AppStrings.onboardingHeroTitlePage2Emphasis,
  AppStrings.onboardingBodyPage2,
  AppStrings.onboardingHeroTitlePage3Prefix,
  AppStrings.onboardingHeroTitlePage3Emphasis,
  AppStrings.onboardingStockBadge,
  AppStrings.onboardingBodyPage3,
  AppStrings.onboardingNextButton,
  AppStrings.onboardingGetStartedButton,
];

/// ข้อความทุกบรรทัดที่เรนเดอร์อยู่จริงใน widget tree ตอนนี้
///
/// อ่านจาก `RichText` ไม่ใช่ `Text` เพราะ `Text` · `Text.rich` · `RichText`
/// ล้วนลงเอยเป็น `RichText` ตอนเรนเดอร์ — เก็บที่ชั้นนี้ชั้นเดียวจึงครอบทั้งสามแบบ
Iterable<String> _renderedText(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText());
}

List<String> _violations(Iterable<String> lines) {
  final offenders = <String>[];
  for (final line in lines) {
    for (final claim in _bannedClaims) {
      // เทียบแบบไม่สนตัวพิมพ์ — `Certified` · `CERTIFIED` · `certified` คือคำอ้าง
      // เดียวกันทั้งหมด · ไม่กระทบคำไทยซึ่ง `toLowerCase()` ไม่เปลี่ยนรูป
      if (line.toLowerCase().contains(claim.toLowerCase())) {
        offenders.add('"$line" → มีคำว่า "$claim"');
      }
    }
  }
  return offenders;
}

void main() {
  test('ข้อความ onboarding ใน AppStrings ไม่มีคำอ้างความแท้ (ADR-0014 D1)', () {
    expect(
      _violations(_onboardingCopy),
      isEmpty,
      reason:
          'พบคำอ้างความแท้ใน AppStrings — ADR-0014 D1 ห้ามอ้างว่า "รับรองว่าเป็นของแท้"\n'
          'หรือ "ตรวจสอบโดยผู้เชี่ยวชาญ" เมื่อไม่มีผู้เชี่ยวชาญที่ระบุตัวได้จริง\n'
          'สิ่งที่เขียนได้คือ "ตรวจอะไร พบอะไร" ไม่ใช่ "รับรองอะไร"',
    );
  });

  testWidgets('ทั้งสามหน้าของ onboarding ไม่แสดงคำอ้างความแท้ (ADR-0014 D1)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingPageViewScreen())),
    );
    await tester.pumpAndSettle();

    final seen = <String>{};
    for (var page = 0; page < 3; page++) {
      seen.addAll(_renderedText(tester));
      if (page < 2) {
        await tester.tap(find.text(AppStrings.onboardingNextButton));
        await tester.pumpAndSettle();
      }
    }

    // กันเทสที่ "เขียวเพราะไม่ได้ดูอะไรเลย" — ถ้าเดินหน้าไม่สำเร็จ เซ็ตจะว่างแล้วผ่านฟรี
    expect(
      seen,
      contains(AppStrings.onboardingGetStartedButton),
      reason: 'เดินไปไม่ถึงหน้าสุดท้าย — เทสนี้ยังไม่ได้ตรวจครบทั้งสามหน้า',
    );

    expect(
      _violations(seen),
      isEmpty,
      reason:
          'มีคำอ้างความแท้ขึ้นจอ onboarding — ADR-0014 D1 ห้ามไว้ทุกช่องทาง\n'
          'ข้อความบน onboarding ต้องบอกว่า "ตรวจอะไร" ไม่ใช่ "รับรองอะไร"',
    );
  });
}
