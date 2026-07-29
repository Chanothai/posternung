/// A single image belonging to a poster listing — plain, no serialization
/// (see `data/models/poster_image_model.dart` for the DTO).
class PosterImage {
  const PosterImage({
    required this.id,
    required this.url,
    required this.isPrimary,
    required this.sortOrder,
  });

  final String id;
  final String url;
  final bool isPrimary;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosterImage &&
          other.id == id &&
          other.url == url &&
          other.isPrimary == isPrimary &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, url, isPrimary, sortOrder);
}
