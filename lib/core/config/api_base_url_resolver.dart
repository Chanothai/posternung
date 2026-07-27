import 'environment.dart';

/// Resolves the `posternung-backend` base URL for [environment].
///
/// Checked first: `--dart-define=API_BASE_URL=...` — use it to point at a
/// local/tunnel backend for testing, or to override the SIT default below
/// for your own machine/network. Falls back to the hardcoded default below
/// when no override is passed. Production resolves to the stable domain by
/// default; UAT has no backend deployed yet.
///
/// **No trailing path segment on any of these** — `BackendAuthDataSource`
/// already prefixes every call with `/api/v1/...`; a base URL ending in
/// `/api/v1` would double it (`.../api/v1/api/v1/auth/firebase` → 404).
String apiBaseUrlFor(Environment environment) {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  return switch (environment) {
    // Points at the developer's own machine on the LAN, running
    // `posternung-backend` locally (e.g. via Docker on port 8000) — there's
    // no deployed SIT backend to hit instead. A real device can't use
    // `127.0.0.1` here (that resolves to the device itself, not this Mac);
    // this LAN IP only works while the device is on the same Wi-Fi and will
    // change with the network, so override it per-machine instead of
    // editing this default:
    // `flutter run --flavor sit --dart-define=API_BASE_URL=http://<your-ip>:8000`
    // Different target, different address: Android Emulator → `10.0.2.2`,
    // iOS Simulator → `127.0.0.1` (both reach the host machine directly).
    Environment.sit => 'http://192.168.68.102:8000',
    Environment.uat => '', // no backend deployed for UAT yet
    Environment.production => 'https://api.posternung.com',
  };
}
