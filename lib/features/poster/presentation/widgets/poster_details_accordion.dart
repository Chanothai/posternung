import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// AC-2 / ADR-0005 §D3 — an accordion of only the fields that actually
/// exist as columns (`provenance`, `size`) plus the free-text
/// `description`, which is where "paper stock"/"fold vs. roll" content
/// lives today (there is no dedicated column for either — D3 explicitly
/// rejects inventing one this round). **Any row whose backing field is
/// `null` is omitted entirely** — never rendered as a "-" placeholder — and
/// the whole accordion is omitted if every field is `null`, since an empty
/// expandable tile with nothing inside it is worse than not showing one.
class PosterDetailsAccordion extends StatelessWidget {
  const PosterDetailsAccordion({
    super.key,
    required this.provenance,
    required this.size,
    required this.description,
  });

  final String? provenance;
  final String? size;
  final String? description;

  bool get _hasAnyRow =>
      provenance != null || size != null || description != null;

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
          if (provenance != null)
            _DetailRow(
              label: AppStrings.posterDetailProvenanceLabel,
              value: provenance!,
            ),
          if (size != null)
            _DetailRow(label: AppStrings.posterDetailSizeLabel, value: size!),
          if (description != null)
            _DetailRow(
              label: AppStrings.posterDetailDescriptionLabel,
              value: description!,
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
