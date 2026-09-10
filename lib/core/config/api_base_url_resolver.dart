import 'environment.dart';

/// Resolves the `posternung-backend` base URL for [environment].
///
/// Checked first: `--dart-define=API_BASE_URL=...`. Production resolves to
/// the stable domain by default; **SIT and UAT have no default at all** and
/// require the override.
///
/// 🔴 SIT deliberately returns `''`, not somebody's LAN IP. It used to
/// return `http://172.20.10.12:8000` — one developer's machine on one
/// network — and that address stopped existing without anything noticing.
/// The failure that produced is the reason this is empty now: a stale IP is
/// *reachable-looking*, so a build carrying it fails at the worst possible
/// place. Google sign-in completes (Firebase is public cloud, so it works on
/// mobile data), `POST /auth/firebase` then goes nowhere, no backend session
/// is established, and `AuthGate` keeps rendering the login screen exactly
/// as ADR-0021 D1 requires. What the user sees is *"I signed in and nothing
/// happened"* — with the real cause two layers away. ‹เจอจริง 2026-09-10›
///
/// An empty base URL fails immediately and legibly instead: Dio raises a
/// `DioException` with no response, `BackendAuthDataSource._guard` maps that
/// to `AuthException(code: 'network_error')`, and the screen says so through
/// the ADR-0017 gate like any other auth error. **Verified, not assumed** —
/// probed against Dio 2026-09-10: `DioExceptionType.unknown`, `status ==
/// null`, which is the exact branch `_guard` turns into `network_error`.
///
/// Pass the address for wherever *your* backend actually is:
/// - เครื่องจริงต่อสาย USB → `adb reverse tcp:8000 tcp:8000` แล้วใช้
///   `http://127.0.0.1:8000` (ทางเดียวที่ได้ผลเมื่อมือถือไม่มี Wi-Fi)
/// - iOS Simulator → `http://127.0.0.1:8000`
/// - Android Emulator → `http://10.0.2.2:8000`
/// - เครื่องจริงบน Wi-Fi วงเดียวกัน → `http://<ipconfig getifaddr en0>:8000`
///
/// `.vscode/launch.json` มี config ครบทุกแบบข้างบนแล้ว (ไฟล์นั้น gitignored
/// จึงถือ IP เฉพาะเครื่องได้โดยไม่ปนเข้า repo)
///
/// **No trailing path segment on any of these** — `BackendAuthDataSource`
/// already prefixes every call with `/api/v1/...`; a base URL ending in
/// `/api/v1` would double it (`.../api/v1/api/v1/auth/firebase` → 404).
String apiBaseUrlFor(Environment environment) {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  return switch (environment) {
    // 🔴 No default on purpose — see the doc comment above. There is no
    // deployed SIT backend, so the address is always machine- and
    // network-specific; anything hardcoded here is a lie the moment the
    // developer changes network, and it fails silently rather than loudly.
    Environment.sit => '',
    Environment.uat => '', // no backend deployed for UAT yet
    Environment.production => 'https://api.posternung.com',
  };
}
