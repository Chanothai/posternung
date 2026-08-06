import '../../../core/error/catalog_exception.dart';
import '../../../core/error/error_display.dart';
import '../../../core/strings/app_strings.dart';

/// Maps a [CatalogException] to a display message via the shared three-step
/// algorithm (ADR-0017 D4/D9 — see `core/error/error_display.dart` for the
/// algorithm; this file owns only the catalog-specific table step 1 reads).
///
/// One table for every screen that renders a [CatalogException] —
/// `poster/`'s detail screen and `home/`'s catalog grid both call this
/// instead of writing `error is CatalogException ? error.message : null`
/// themselves, which is exactly the three-times-duplicated pattern
/// ADR-0017 D9 replaces. [fallback] is still per-screen (each has its own
/// static "something went wrong" copy) — only the mapping *algorithm* and
/// the *code table* are shared.
String catalogErrorDisplayMessage(
  CatalogException e, {
  required String fallback,
}) => resolveErrorDisplay(
  e.displayMessage,
  code: e.code,
  codeMessages: _catalogMessages,
  fallback: fallback,
).message;

/// `null` if [error] isn't a [CatalogException] — call sites already fall
/// back to their own static copy in that case (there is no ADR-0017 `code`
/// to look up), same as the previous `error is CatalogException ? ... :
/// null` inline check this replaces.
String? catalogErrorMessageFor(Object? error, {required String fallback}) =>
    switch (error) {
      CatalogException e => catalogErrorDisplayMessage(e, fallback: fallback),
      _ => null,
    };

const _catalogMessages = <String, String>{
  // Transport-level codes thrown by PosterRemoteDataSource._guard /
  // PosterRepositoryImpl — not backend `error_code`s, so they need this
  // feature's own Thai text rather than relying on `displayMessage`.
  'network_error': AppStrings.authErrorNetwork,
  'server_error': AppStrings.authErrorServer,
};
