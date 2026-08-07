// 🔴 เทสชั่วคราว — ห้ามลบโดยไม่อ่าน ADR-0014 D5.1 ก่อน
//
// **ห้ามแสดง `verification_status` / `verification_note` บนจอ จนกว่า OD-2 ของ
// ADR-0014 จะถูกปิดว่า "ข้อความผ่านการตรวจทางกฎหมายแล้ว"**
//
// INF-12 (R1) ทำให้สองฟิลด์นี้โผล่ใน `PosterDetailResponse` ของ API contract แล้ว
// แต่ **การเห็นฟิลด์ในสัญญาไม่ใช่ใบอนุญาตให้เอาไปแสดง** — รอบ UI (R2) ยังไม่ได้รับ
// อนุญาตให้เริ่ม เพราะข้อความที่จะใช้ยังไม่ผ่านการตรวจทางกฎหมาย และตัว ADR ทั้งฉบับ
// เขียนขึ้นเพื่อบอกว่าอย่าอ้างสิ่งที่พิสูจน์ไม่ได้ (D1)
//
// ทำไมต้องเป็นเทส ไม่ใช่แค่ให้ `code-critic` ดู: critic เป็น agent ที่ตรวจตอนรีวิว
// ส่วนเทสรันทุกครั้งใน CI · และ `project-gotchas` §3 บันทึกไว้เองว่า "กฎที่บอกว่า
// ต้องไม่แสดง ต้องมี assertion เชิงลบเสมอ"
//
// ✅ **เมื่อ OD-2 ผ่านแล้ว ให้ลบไฟล์นี้ทิ้งพร้อมกับ commit ที่เปิด R2** — ไม่ใช่ปล่อย
// ค้างไว้ให้คนรุ่นหลังเดาว่าทำไมฟีเจอร์ถึงถูกห้าม · กฎการแสดงผลของ R2 พร้อมแล้วใน
// ADR-0014 D9 (เจ็ดข้อ) ไม่ต้องตัดสินใหม่

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// โทเคนที่ห้ามปรากฏใน `lib/`
///
/// 🔴 จงใจไม่ match คำว่า `verification` ลอย ๆ — `lib/features/auth/presentation/
/// screens/otp_verification_screen.dart` มีอยู่จริงและไม่เกี่ยวกับ ADR-0014 เลย
/// การ match กว้างกว่านี้จะได้เทสที่แดงด้วยเหตุผลผิด แล้วคนถัดไปจะปิดมันทิ้ง
/// 🔴 **ต้องเติมชื่อใหม่ทุกครั้งที่ backend rename ฟิลด์** — ด่านนี้ผูกกับ *สตริง*
/// ไม่ใช่กับฟิลด์ · ADR-0014 D22 เปลี่ยน `verification_note` → `reference_note`
/// เมื่อ 2026-08-07 · ถ้าเก็บแต่ชื่อเก่า ด่านจะครอบไม่ถึงชื่อใหม่ **โดยไม่มีอะไรฟ้อง**
/// (ฝั่ง backend กันกับดักตัวเดียวกันไว้แล้วที่
/// `tests/unit/test_seed_importer_omits_unverified_adr0009_fields.py`)
/// · เก็บชื่อเก่าไว้ด้วย เพราะโค้ดเก่าที่ยังเขียนชื่อเดิมก็ต้องยังถูกจับ
const _forbiddenTokens = <String>[
  'verification_status',
  'verificationStatus',
  'verification_note',
  'verificationNote',
  'reference_note',
  'referenceNote',
];

/// ไฟล์เดียวที่ได้รับยกเว้น — ตัวเทสนี้เอง ซึ่งต้องเขียนโทเคนออกมาตรง ๆ เพื่อไล่หามัน
///
/// เขียนเป็น path เต็มจาก root ไม่ใช่แค่ชื่อไฟล์ เพื่อไม่ให้ไฟล์ชื่อเดียวกันที่อื่น
/// ได้รับยกเว้นตามไปด้วยโดยไม่ตั้งใจ
const _selfPath =
    'test/features/poster/verification_fields_not_wired_test.dart';

void main() {
  test('lib/ และ test/ ยังไม่อ้าง verification_* เลย (ADR-0014 D5.1)', () {
    // 🔴 สแกน `test/` ด้วย ไม่ใช่แค่ `lib/` — มติผู้ใช้ 2026-08-05:
    // "ถ้ามีคนเขียน test ที่ assert ว่า verification_* แสดงผลได้ นั่นคือสัญญาณว่า
    //  กำลังจะต่อ UI ก่อน OD-2 ผ่าน" · เทสที่มาก่อนโค้ดคือสัญญาณที่มาเร็วกว่าโค้ด
    final roots = [Directory('lib'), Directory('test')];
    for (final dir in roots) {
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'ต้องรันเทสจาก root ของ package (ที่เดียวกับ pubspec.yaml)',
      );
    }

    final offenders = <String>[];
    for (final entity in roots.expand((dir) => dir.listSync(recursive: true))) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith(_selfPath)) continue;
      final source = entity.readAsStringSync();
      for (final token in _forbiddenTokens) {
        if (source.contains(token)) {
          offenders.add('${entity.path} → $token');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบการอ้าง verification_* ใน lib/ หรือ test/ — ADR-0014 D5.1 ห้ามแสดงฟิลด์นี้บนจอ\n'
          'จนกว่า OD-2 (ตรวจข้อความทางกฎหมาย) จะถูกปิดว่าผ่านแล้ว\n'
          'ถ้า OD-2 ผ่านแล้วจริง: อัปเดต ADR-0014 ก่อน แล้วลบไฟล์เทสนี้ทิ้งทั้งไฟล์\n'
          'ห้ามแก้ _forbiddenTokens ให้เทสเขียวโดยที่ ADR ยังไม่เปลี่ยน\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });
}
