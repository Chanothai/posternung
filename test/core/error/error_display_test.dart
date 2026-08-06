import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/error_display.dart';

void main() {
  group('resolveErrorDisplay — ADR-0017 D4 three-step order', () {
    const codeMessages = {'known_code': 'ข้อความไทยที่รู้จัก'};
    const fallback = 'ข้อความสำรอง';

    test('step 1 — a known code maps to its Thai text', () {
      final result = resolveErrorDisplay(
        null,
        code: 'known_code',
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(result.message, 'ข้อความไทยที่รู้จัก');
      expect(result.code, 'known_code');
    });

    test('step 1 wins over step 2 even when displayMessage is also present — '
        'the order is fixed, not "whichever is set"', () {
      final result = resolveErrorDisplay(
        'ข้อความจาก backend ที่ไม่ควรถูกใช้ตรงนี้',
        code: 'known_code',
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(result.message, 'ข้อความไทยที่รู้จัก');
    });

    test(
      'step 2 — an unknown code with a non-blank displayMessage uses it',
      () {
        final result = resolveErrorDisplay(
          'ข้อความจาก backend envelope',
          code: 'unknown_code',
          codeMessages: codeMessages,
          fallback: fallback,
        );

        expect(result.message, 'ข้อความจาก backend envelope');
        expect(result.code, 'unknown_code');
      },
    );

    test('step 2 trims surrounding whitespace before using displayMessage', () {
      final result = resolveErrorDisplay(
        '   ข้อความมีช่องว่างรอบ ๆ   ',
        code: 'unknown_code',
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(result.message, 'ข้อความมีช่องว่างรอบ ๆ');
    });

    test('step 3 — an unknown code with a null displayMessage falls back', () {
      final result = resolveErrorDisplay(
        null,
        code: 'unknown_code',
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(result.message, fallback);
      expect(result.code, 'unknown_code');
    });

    test('step 3 — an unknown code with a blank/whitespace-only displayMessage '
        'falls back, same as null (a technically-non-null empty string is not '
        'a real message)', () {
      final result = resolveErrorDisplay(
        '   ',
        code: 'unknown_code',
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(result.message, fallback);
    });

    test('code is always echoed back verbatim, on every step', () {
      expect(
        resolveErrorDisplay(
          null,
          code: 'known_code',
          codeMessages: codeMessages,
          fallback: fallback,
        ).code,
        'known_code',
      );
      expect(
        resolveErrorDisplay(
          'x',
          code: 'unknown_code',
          codeMessages: codeMessages,
          fallback: fallback,
        ).code,
        'unknown_code',
      );
      expect(
        resolveErrorDisplay(
          null,
          code: 'unknown_code',
          codeMessages: codeMessages,
          fallback: fallback,
        ).code,
        'unknown_code',
      );
    });

    test('an empty codeMessages table still resolves via step 2/3', () {
      final result = resolveErrorDisplay(
        'displayMessage only',
        code: 'any_code',
        codeMessages: const {},
        fallback: fallback,
      );

      expect(result.message, 'displayMessage only');
    });
  });
}
