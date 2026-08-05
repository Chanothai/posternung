import 'package:flutter/material.dart';

import '../../../../core/catalog/poster_type.dart';
import '../../../../core/catalog/release_region.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// AC-2 / ADR-0005 §D3 · ADR-0011 §D1′ — a flat, ungrouped accordion of
/// every field that has no other home on screen. `year`/`size_format`
/// moved to the poster-detail subtitle (§D4′) and `release_date` is never
/// shown (§D3), so what's left here no longer needs the two-group split
/// the original §D1 proposed — see the amendment for why.
///
/// Row order (fixed, not alphabetical — matches §D1′ exactly):
/// `poster_type` · `size` · `release_date_text` · `copyright_year` ·
/// `provenance` · `restoration_note` · `description` · `release_region`
/// (only when it's specifically [ReleaseRegion.unknown] — §D9).
///
/// **Any row whose backing field is `null` is omitted entirely** — never
/// rendered as a "-" placeholder — and the whole accordion is omitted if
/// every field is `null`/absent, since an empty expandable tile with
/// nothing inside it is worse than not showing one.
///
/// Blank counts as missing too, not just `null` (code-critic round 1, M2):
/// the same precedent that fixed `poster_detail_screen.dart`'s "2010s •"
/// bug (a `studio` of `""` on the wire, not `null`) applies to every
/// `String?` row here — `size` · `release_date_text` · `provenance` ·
/// `restoration_note` · `description` — so a whitespace-only value is
/// trimmed and treated the same as `null`, both for hiding its own row and
/// for [_hasAnyRow].
class PosterDetailsAccordion extends StatelessWidget {
  const PosterDetailsAccordion({
    super.key,
    required this.posterType,
    required this.size,
    required this.releaseDateText,
    required this.copyrightYear,
    required this.provenance,
    required this.restorationNote,
    required this.description,
    required this.releaseRegion,
  });

  final PosterType? posterType;
  final String? size;
  final String? releaseDateText;
  final int? copyrightYear;
  final String? provenance;
  final String? restorationNote;
  final String? description;

  /// Only ever contributes a row when it equals [ReleaseRegion.unknown]
  /// (ADR-0011 §D9) — a real region (`US`/`TH`/…) lives in the subtitle
  /// instead, and `null` shows nowhere at all.
  final ReleaseRegion? releaseRegion;

  /// `null` or whitespace-only → `null`. See the class doc's M2 note.
  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? get _size => _blankToNull(size);
  String? get _releaseDateText => _blankToNull(releaseDateText);
  String? get _provenance => _blankToNull(provenance);
  String? get _restorationNote => _blankToNull(restorationNote);
  String? get _description => _blankToNull(description);

  bool get _releaseRegionUnknownRow => releaseRegion == ReleaseRegion.unknown;

  bool get _hasAnyRow =>
      posterType != null ||
      _size != null ||
      _releaseDateText != null ||
      copyrightYear != null ||
      _provenance != null ||
      _restorationNote != null ||
      _description != null ||
      _releaseRegionUnknownRow;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyRow) return const SizedBox.shrink();

    return Theme(
      // Flatten the default divider lines ExpansionTile draws above/below
      // itself — this screen already separates sections with spacing.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        title: Text(
          AppStrings.posterDetailDetailsSectionTitle,
          style: AppTextStyles.homeSectionHeading,
        ),
        children: [
          if (posterType != null)
            _DetailRow(
              label: AppStrings.posterDetailPosterTypeLabel,
              value: posterType!.label,
            ),
          if (_size != null)
            _DetailRow(label: AppStrings.posterDetailSizeLabel, value: _size!),
          if (_releaseDateText != null)
            _DetailRow(
              label: AppStrings.posterDetailReleaseDateTextLabel,
              value: _releaseDateText!,
            ),
          if (copyrightYear != null)
            _DetailRow(
              label: AppStrings.posterDetailCopyrightYearLabel,
              value: '${copyrightYear!}',
            ),
          if (_provenance != null)
            _DetailRow(
              label: AppStrings.posterDetailProvenanceLabel,
              value: _provenance!,
            ),
          if (_restorationNote != null)
            _DetailRow(
              label: AppStrings.posterDetailRestorationNoteLabel,
              value: _restorationNote!,
            ),
          if (_description != null)
            _DetailRow(
              label: AppStrings.posterDetailDescriptionLabel,
              value: _description!,
            ),
          if (_releaseRegionUnknownRow)
            _DetailRow(
              label: AppStrings.posterDetailReleaseRegionLabel,
              value: releaseRegion!.label,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.inputLabel),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.bodyDescription),
        ],
      ),
    );
  }
}
