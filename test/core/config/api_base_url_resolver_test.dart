import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/config/api_base_url_resolver.dart';
import 'package:posternung/core/config/environment.dart';

void main() {
  group('apiBaseUrlFor', () {
    // No --dart-define=API_BASE_URL is passed in this test run, so these
    // exercise the hardcoded per-environment defaults. The override branch
    // is compile-time (String.fromEnvironment) and can't be flipped at test
    // runtime — verified manually via
    // `flutter run --dart-define=API_BASE_URL=...` instead.
    // 🔴 เชิงลบโดยตั้งใจ — SIT ต้อง *ไม่มี* default
    //
    // เดิมข้อนี้ล็อกค่า `http://172.20.10.12:8000` ไว้ ซึ่งเป็น IP ของเครื่อง
    // นักพัฒนาคนหนึ่งบนเครือข่ายหนึ่ง · พอ IP นั้นตาย เทสยัง**เขียว**อยู่ทั้งที่แอป
    // ต่อ backend ไม่ได้แล้ว ⇒ เทสกำลังคุ้มครองค่าที่ผิด ไม่ใช่คุ้มครองพฤติกรรม
    //
    // ที่ต้องคุ้มครองจริงคือ "ห้ามมีใครใส่ที่อยู่ของเครื่องตัวเองกลับเข้ามา"
    // ‹เปลี่ยนเกณฑ์ 2026-09-10 หลังอาการ "ล็อกอิน Google ผ่านแต่ค้างหน้า login"›
    test('sit has no default — the address is always machine-specific', () {
      expect(apiBaseUrlFor(Environment.sit), '');
    });

    test('no environment default hardcodes a private/LAN address', () {
      // closed-world: ไล่ทุกค่าใน enum ไม่ใช่แค่ที่นึกออก — enum โตขึ้นเมื่อไร
      // ข้อนี้ครอบเองทันที
      for (final env in Environment.values) {
        final url = apiBaseUrlFor(env);
        if (url.isEmpty) continue;
        expect(
          RegExp(
            r'^https?://(10\.|127\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|localhost)',
          ).hasMatch(url),
          isFalse,
          reason:
              'default ของ $env คือ "$url" ซึ่งเป็นที่อยู่เฉพาะเครื่อง/เครือข่าย — '
              'ส่งผ่าน --dart-define=API_BASE_URL แทน (ดู doc comment ของ apiBaseUrlFor)',
        );
      }
    });

    test('uat has no backend deployed yet', () {
      expect(apiBaseUrlFor(Environment.uat), '');
    });

    test('production defaults to the production API domain', () {
      expect(
        apiBaseUrlFor(Environment.production),
        'https://api.posternung.com',
      );
    });
  });
}
