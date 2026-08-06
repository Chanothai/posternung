/// Domain-level exception for catalog (poster) failures. Data-layer
/// datasources/repositories catch SDK-specific exceptions (e.g.
/// `DioException`) and rethrow this instead, so nothing above the
/// repository boundary depends on Dio — same pattern as `AuthException`,
/// including the three-field split (ADR-0017 D1); see that class's doc
/// comment for what each field is for and why `message` was removed rather
/// than kept as a fourth field.
class CatalogException implements Exception {
  const CatalogException({
    required this.code,
    this.displayMessage,
    this.debugDetail,
  });

  final String code;
  final String? displayMessage;
  final String? debugDetail;

  @override
  String toString() => 'CatalogException(code: $code)';
}
