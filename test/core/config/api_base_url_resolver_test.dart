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
    test('sit points at the local backend over the developer LAN', () {
      expect(apiBaseUrlFor(Environment.sit), 'http://192.168.68.102:8000');
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
