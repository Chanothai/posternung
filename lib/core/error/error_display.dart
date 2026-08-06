/// What a screen shows for a failed error state: a friendly Thai [message]
/// plus the raw [code] it came from (features render `code` however they
/// like — see e.g. `AuthErrorBanner`'s muted second line — or not at all).
typedef ErrorDisplay = ({String message, String code});

/// The one algorithm allowed for turning `code`/`displayMessage` into what a
/// screen shows (ADR-0017 D4). This is an **allowlist**, not a denylist — a
/// regex that scrubs URLs/tokens out of arbitrary text was rejected (D4/A5)
/// because a missed case fails silently; this instead only ever surfaces
/// text that was already known-safe *before* the call, in a fixed order
/// with no fourth branch:
///
/// 1. [code] → [codeMessages] — a **feature-owned** table of known codes to
///    Thai text (e.g. auth's Firebase-code map, catalog's network/server-error
///    map). Owned per-feature (D9), not here, so a new feature's codes don't
///    require touching this file.
/// 2. [displayMessage] — used only if step 1 missed. Callers must only ever
///    populate this from a backend `{error_code, message}` envelope (D2) —
///    this function has no way to enforce that; it trusts the caller.
/// 3. [fallback] — a static `AppStrings` constant, used if both above missed.
///
/// [debugDetail] is deliberately not a parameter here at all — it is never
/// legal to render (D7), so there is no path through this function that can
/// leak it onto a screen by accident.
///
/// [displayMessage] is positional here, not named, on purpose: the D10
/// source scan (`test/core/error_message_safety_test.dart`) looks
/// for that field name written as a named constructor argument, to enforce
/// that it's only ever populated from the two backend-envelope datasources
/// (D2's allowlist). Naming this parameter the same way would make the same
/// text pattern appear at every call site that merely *forwards* the field
/// to this function — this file and the two feature mapper files that call
/// it — which isn't a violation of D2 (they don't originate the value, they
/// just relay it), but would be indistinguishable from one to a text-level
/// scan.
ErrorDisplay resolveErrorDisplay(
  String? displayMessage, {
  required String code,
  required Map<String, String> codeMessages,
  required String fallback,
}) {
  final mapped = codeMessages[code];
  if (mapped != null) return (message: mapped, code: code);

  final trimmedDisplayMessage = displayMessage?.trim();
  if (trimmedDisplayMessage != null && trimmedDisplayMessage.isNotEmpty) {
    return (message: trimmedDisplayMessage, code: code);
  }

  return (message: fallback, code: code);
}
