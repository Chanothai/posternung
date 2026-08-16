// ADR-0026 Amendment §A-D9 (1) — the permanent, structural reason the (ค)
// fail-closed test lives at SCR-05 and not SCR-03: `PosterListItem` (the
// `GET /posters` shape, `PosterSummary`/`PosterSummaryModel` on this side)
// has **no `images` array and no `kind` at all** — there is nowhere to put
// a "primary with the wrong kind" mock at the Home layer, because the
// field doesn't exist there structurally, not because nobody wrote the
// mock. `_primary_image_url()` is picked on the *backend*, already covered
// there (`tests/integration/test_poster_api.py`).
//
// Scoped to the list/home files only (`poster_summary.dart`,
// `poster_summary_model.dart`, `paginated_posters_model.dart`,
// `lib/features/home/`) — not the full `lib/` the way
// `verification_fields_not_wired_test.dart` scans, because `kind` and
// `images` legitimately exist on the poster *detail* side (SCR-05) and a
// wider scan would fail for the wrong reason.
//
// If this test ever goes red, that's the signal the amendment predicted:
// someone added `images`/`kind` to the list endpoint, which means (ค)'s
// reasoning needs re-reading before wiring anything new on top of it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tokens that would only appear in these files if `images`/`kind` had
/// actually reached the list/home layer — not just the *word* "images" or
/// "kind", which the doc comments on `poster_summary.dart` and
/// `poster_summary_model.dart` already use today to explain that the field
/// is *absent* (verified zero-hit against these exact files before writing
/// this list, so a literal `contains('kind')`/`contains('images')` scan
/// would have been a false-positive trap from the very first run).
const _forbiddenTokens = <String>[
  'PosterImageKind', // the enum type reaching this layer at all
  'List<PosterImage>', // the entity's image-list type
  'List<PosterImageModel>', // the DTO's image-list type
  'this.images', // a constructor param actually naming an images field
  "'kind'", // a JSON key literal for kind, single-quoted
  '"kind"', // same, double-quoted
];

const _scannedPaths = <String>[
  'lib/features/poster/domain/entities/poster_summary.dart',
  'lib/features/poster/data/models/poster_summary_model.dart',
  'lib/features/poster/data/models/paginated_posters_model.dart',
];

const _scannedDirs = <String>['lib/features/home'];

void main() {
  test('the list/home layer has no images or kind field — the structural '
      'reason ADR-0026 §A-D9 (ค) is tested at SCR-05, not SCR-03', () {
    for (final path in _scannedPaths) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            'ต้องรันเทสจาก root ของ package (ที่เดียวกับ pubspec.yaml) '
            'และไฟล์นี้ต้องมีอยู่จริง: $path',
      );
    }

    final files = <File>[
      for (final path in _scannedPaths) File(path),
      for (final dirPath in _scannedDirs)
        for (final entity in Directory(dirPath).listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart')) entity,
    ];
    expect(files, isNotEmpty);

    final offenders = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final token in _forbiddenTokens) {
        if (source.contains(token)) {
          offenders.add('${file.path} → $token');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบ images/kind เข้าถึง list/home layer แล้ว — ADR-0026 §A-D9 (1) '
          'เขียนไว้ว่า (ค) ไม่ได้ทดสอบที่ SCR-03 เพราะไม่มีที่ให้ mock ทาง '
          'โครงสร้าง ถ้าฟิลด์นี้เข้ามาแล้วจริง ต้องกลับไปอ่าน A-D9 ก่อนต่อ '
          'อะไรทับ ไม่ใช่ปล่อยเทสนี้ให้แดงเงียบ ๆ\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });
}
