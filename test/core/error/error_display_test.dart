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

  group('resolveErrorDisplay — closed-world: nothing outside step 3 leaks '
      'through when neither step 1 nor step 2 matches', () {
    const codeMessages = {'known_code': 'ข้อความไทยที่รู้จัก'};
    const fallback = 'ข้อความสำรอง';
    const unmappedCode = 'unknown_code';

    /// True when [result] is exactly what step 3 (fallback) must produce for
    /// a call with [code] that misses both step 1 and step 2: the message
    /// equals [fallback] verbatim, and the code is echoed back unchanged.
    ///
    /// Only two clauses — not four. An earlier version of this predicate
    /// also asserted `result.message != code` and
    /// `result.message != fedDisplayMessage`, meant as an explicit guard
    /// against a secret fourth branch that echoes raw input instead of
    /// using fallback (the shape of BL-99). Those two clauses were **dead**
    /// in every case this group exercises: a clause can only go false when
    /// `fallback == code` or `fallback == fedDisplayMessage`, and neither
    /// ever holds for the fixtures used here (`fallback` is
    /// 'ข้อความสำรอง'; the codes/inputs fed in are 'unknown_code', '', and
    /// '   ') — so removing them changes nothing any control here can
    /// observe (found during review, same class of bug as the gap this
    /// file was written to close: a check that reads like it tests
    /// something but never can). `result.message == fallback` already
    /// covers "not a raw-input echo" on its own: a secret branch that
    /// echoes `code`/the fed `displayMessage` instead of using `fallback`
    /// only produces `message == fallback` by coincidence if `fallback`
    /// happened to equal that raw value — which it never does for any
    /// fixture in this group — so the first clause alone already fails for
    /// that mutant (verified: mutating `error_display.dart`'s step 3 to
    /// return `code` instead of `fallback` kills every real-case test
    /// below through this clause). Do not add the two removed clauses back
    /// to "restore" this guard — they were never load-bearing.
    ///
    /// Shared by the three real-case tests below and their own
    /// positive/negative control, on purpose (test-quality §3.1, same
    /// lesson as `isEnvelopeClassWithPrivateCtor` in
    /// `error_message_safety_test.dart`): weakening either clause here is
    /// provably caught by the control instead of only by the real case.
    bool isFallbackResult(
      ErrorDisplay result, {
      required String code,
      required String fallback,
    }) => result.message == fallback && result.code == code;

    test('displayMessage is null (an unmapped code) → falls back verbatim, '
        'with code echoed back — a secret branch that echoed the raw code '
        'or displayMessage instead (the shape of BL-99) would already fail '
        'the message==fallback half of this check, since fallback never '
        'equals either raw value in this fixture', () {
      final result = resolveErrorDisplay(
        null,
        code: unmappedCode,
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(
        isFallbackResult(result, code: unmappedCode, fallback: fallback),
        isTrue,
        reason:
            'displayMessage=null ต้องได้ fallback เป๊ะ ๆ และ code ต้อง echo '
            'กลับ ($unmappedCode)',
      );
    });

    test('displayMessage is an empty string (an unmapped code) → falls '
        'back verbatim, with code echoed back — a secret branch that '
        'echoed the raw code or displayMessage instead (the shape of '
        'BL-99) would already fail the message==fallback half of this '
        'check, since fallback never equals either raw value in this '
        'fixture', () {
      final result = resolveErrorDisplay(
        '',
        code: unmappedCode,
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(
        isFallbackResult(result, code: unmappedCode, fallback: fallback),
        isTrue,
        reason:
            'displayMessage="" ต้องได้ fallback เป๊ะ ๆ และ code ต้อง echo '
            'กลับ ($unmappedCode)',
      );
    });

    test('displayMessage is whitespace-only (an unmapped code) → falls '
        'back verbatim, with code echoed back — a secret branch that '
        'echoed the raw code or displayMessage instead (the shape of '
        'BL-99) would already fail the message==fallback half of this '
        'check, since fallback never equals either raw value in this '
        'fixture', () {
      const blank = '   ';
      final result = resolveErrorDisplay(
        blank,
        code: unmappedCode,
        codeMessages: codeMessages,
        fallback: fallback,
      );

      expect(
        isFallbackResult(result, code: unmappedCode, fallback: fallback),
        isTrue,
        reason:
            'displayMessage="   " ต้องได้ fallback เป๊ะ ๆ และ code ต้อง '
            'echo กลับ ($unmappedCode)',
      );
    });

    test('positive/negative control for isFallbackResult above — proves '
        'both remaining clauses actually discriminate, each on its own: '
        'a mutant that gets the message wrong (echoes raw code instead of '
        'fallback — the shape of M13) and a mutant that gets the code '
        'wrong (right message, but fails to echo code back) must both be '
        'rejected, and a correct result must be accepted, rather than the '
        'predicate being vacuously true for any result', () {
      expect(
        isFallbackResult(
          (message: fallback, code: unmappedCode),
          code: unmappedCode,
          fallback: fallback,
        ),
        isTrue,
        reason:
            'ผลลัพธ์ที่ถูกต้องจริง (message=fallback, code=echo) ต้องผ่าน — '
            'กัน predicate ที่ return false เสมอโดยไม่ได้ตรวจอะไรจริง',
      );
      expect(
        isFallbackResult(
          (message: unmappedCode, code: unmappedCode),
          code: unmappedCode,
          fallback: fallback,
        ),
        isFalse,
        reason:
            'mutant ที่คืน code แทน fallback ใน message (รูปเดียวกับ M13) '
            'ต้องไม่ผ่าน — เคสนี้จะแดงถ้ามีคนถอด clause '
            '`result.message == fallback` ออกจาก predicate ร่วม',
      );
      expect(
        isFallbackResult(
          (message: fallback, code: 'something_else'),
          code: unmappedCode,
          fallback: fallback,
        ),
        isFalse,
        reason:
            'mutant ที่ message ถูก (=fallback) แต่ code ไม่ได้ echo กลับ '
            '(ได้ "something_else" แทน "$unmappedCode") ต้องไม่ผ่าน — เคสนี้ '
            'จะแดงถ้ามีคนถอด clause `result.code == code` ออกจาก predicate '
            'ร่วม (M14)',
      );
    });
  });
}
