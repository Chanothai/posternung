/// Domain-level exception for catalog (poster) failures. Data-layer
/// datasources/repositories catch SDK-specific exceptions (e.g.
/// `DioException`) and rethrow this instead, so nothing above the
/// repository boundary depends on Dio — same pattern as `AuthException`.
class CatalogException implements Exception {
  const CatalogException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}
