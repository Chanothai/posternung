import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/size_format.dart';

void main() {
  test('apiValue round-trips through sizeFormatFromApi for every value', () {
    for (final format in SizeFormat.values) {
      expect(sizeFormatFromApi(format.apiValue), format);
    }
  });

  test('apiValue is the exact backend UPPERCASE wire value', () {
    expect(SizeFormat.oneSheet.apiValue, 'ONE_SHEET');
    expect(SizeFormat.halfSheet.apiValue, 'HALF_SHEET');
    expect(SizeFormat.insert.apiValue, 'INSERT');
    expect(SizeFormat.quad.apiValue, 'QUAD');
    expect(SizeFormat.other.apiValue, 'OTHER');
    expect(SizeFormat.unknown.apiValue, 'UNKNOWN');
  });

  test('sizeFormatFromApi returns null for a null input', () {
    expect(sizeFormatFromApi(null), isNull);
  });

  test('sizeFormatFromApi returns null (not a throw) for an unrecognized '
      'value', () {
    expect(sizeFormatFromApi('THREE_SHEET'), isNull);
  });

  // ADR-0009 §D4 — no measured size exists in the system yet; the label
  // must never claim one by appending inches.
  test('no label contains an inch dimension', () {
    for (final format in SizeFormat.values) {
      expect(format.label, isNot(contains('"')));
      expect(format.label, isNot(contains('x')));
      expect(format.label, isNot(contains('นิ้ว')));
    }
  });
}
