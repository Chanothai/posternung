import 'environment.dart';

/// Resolves the `posternung-backend` base URL for [environment].
///
/// Checked first: `--dart-define=API_BASE_URL=...` — use it to point at a
/// local/tunnel backend for testing, or to wire SIT/UAT once they deploy.
/// Falls back to the hardcoded default below when no override is passed.
/// Production resolves to the stable domain by default; SIT/UAT have no
/// backend deployed yet.
String apiBaseUrlFor(Environment environment) {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  return switch (environment) {
    Environment.sit => '', // no backend deployed for SIT yet
    Environment.uat => '', // no backend deployed for UAT yet
    Environment.production => 'https://api.posternung.com',
  };
}
