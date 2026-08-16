import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/poster/domain/entities/poster_image.dart';
import 'package:posternung/features/poster/domain/entities/poster_image_kind.dart';

void main() {
  PosterImage image({PosterImageKind? kind}) => PosterImage(
    id: 'img-1',
    url: 'https://example.invalid/1.jpg',
    isPrimary: true,
    sortOrder: 0,
    kind: kind,
  );

  group('PosterImage equality', () {
    // If `==`/`hashCode` are ever regenerated/hand-edited without adding
    // `kind`, these two tests are the ones that go red — everything else
    // that constructs a PosterImage with a fixed `kind` would keep passing
    // silently.
    test('two images differing only by kind are not equal', () {
      expect(
        image(kind: PosterImageKind.front),
        isNot(image(kind: PosterImageKind.back)),
      );
      expect(image(kind: PosterImageKind.front), isNot(image()));
    });

    test('two images with the same kind (including both null) are equal '
        'and share a hashCode', () {
      expect(
        image(kind: PosterImageKind.front),
        image(kind: PosterImageKind.front),
      );
      expect(
        image(kind: PosterImageKind.front).hashCode,
        image(kind: PosterImageKind.front).hashCode,
      );
      expect(image(), image());
      expect(image().hashCode, image().hashCode);
    });
  });
}
