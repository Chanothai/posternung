import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/config/environment.dart';

void main() {
  group('resolveEnvironment', () {
    test('resolves production for the "production" flavor', () {
      expect(
        resolveEnvironment(flavorOverride: 'production'),
        Environment.production,
      );
    });

    test('resolves uat for the "uat" flavor', () {
      expect(resolveEnvironment(flavorOverride: 'uat'), Environment.uat);
    });

    test('resolves sit for the "sit" flavor', () {
      expect(resolveEnvironment(flavorOverride: 'sit'), Environment.sit);
    });

    test('falls back to sit for an unrecognized flavor', () {
      expect(resolveEnvironment(flavorOverride: 'bogus'), Environment.sit);
    });

    test('falls back to sit when no flavor is available', () {
      expect(resolveEnvironment(flavorOverride: null), Environment.sit);
    });
  });

  group('EnvironmentX.label', () {
    test('returns a human-readable label per environment', () {
      expect(Environment.sit.label, 'SIT');
      expect(Environment.uat.label, 'UAT');
      expect(Environment.production.label, 'Production');
    });
  });
}
