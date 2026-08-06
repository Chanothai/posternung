import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;

/// The one way `debugDetail` is allowed to leave the app (ADR-0017 D7): a
/// `kDebugMode`-guarded debug-console log line, never a widget. Every data
/// layer guard that populates `AuthException`/`CatalogException.debugDetail`
/// wraps the value in this at the `throw` site —
/// `debugDetail: logDebugDetail(e.message, source: 'email_password_signin')`
/// — instead of hand-rolling its own `if (kDebugMode) { developer.log(...) }`
/// block, so there is exactly one implementation of "log it, then hand the
/// same value back to be stored on the exception" rather than eighteen
/// slightly-different copies.
///
/// Lives in `core/error/`, not `core/widgets/` or any `presentation/`
/// directory — the ADR-0017 D10 source scan bans referencing `debugDetail`
/// under those, precisely so a render path can never read it. A data-layer
/// datasource/repository is not that path.
String? logDebugDetail(String? debugDetail, {required String source}) {
  if (debugDetail != null && kDebugMode) {
    developer.log(debugDetail, name: source);
  }
  return debugDetail;
}
