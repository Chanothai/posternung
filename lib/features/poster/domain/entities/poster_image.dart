import 'poster_image_kind.dart';

/// A single image belonging to a poster listing — plain, no serialization
/// (see `data/models/poster_image_model.dart` for the DTO).
class PosterImage {
  const PosterImage({
    required this.id,
    required this.url,
    required this.isPrimary,
    required this.sortOrder,
    this.kind,
  });

  final String id;
  final String url;
  final bool isPrimary;
  final int sortOrder;

  /// What this image shows (ADR-0026 §D1) — `null` when the backend sends
  /// an unrecognized/future `kind` value, when the field is absent, or when
  /// this instance predates ADR-0026 (older call sites that don't pass
  /// `kind` at all). See `poster_image_kind.dart` for why `null` must never
  /// throw and must never be treated as an error.
  final PosterImageKind? kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosterImage &&
          other.id == id &&
          other.url == url &&
          other.isPrimary == isPrimary &&
          other.sortOrder == sortOrder &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(id, url, isPrimary, sortOrder, kind);
}
