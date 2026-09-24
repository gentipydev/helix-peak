import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/variant_evidence.dart';

/// What each source is, and every caveat the walk has to make about them —
/// written once.
///
/// These sentences used to be spread over every sheet: "not a health
/// assessment" five times, what AVI is four, what ESM is seven. Now a sheet's
/// info button explains its own model's scale and nothing else, and this is
/// the one place the rest is said: the overview's footer and the About sheet.
class SourcesNote extends StatelessWidget {
  const SourcesNote({this.snapshotDate, this.included = true, super.key});

  /// The ClinVar snapshot's date, once one has loaded.
  final String? snapshotDate;

  /// Whether the gene has a ClinVar snapshot at all. One still loading, or
  /// one that failed, is included and simply has no date to give yet: "not
  /// yet included" is a different state and says something else (R9.3).
  final bool included;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? body = theme.textTheme.bodySmall?.copyWith(
      fontFamily: AppTypography.sansFamily,
    );
    final TextStyle? lead = body?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    );
    Widget paragraph(String name, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '$name  ', style: lead),
            TextSpan(text: text),
          ],
        ),
        style: body,
      ),
    );
    return Column(
      key: const ValueKey<String>('sources-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        paragraph(
          'ESM-2',
          '650M, masked marginals. Per residue: constraint 0–1, min–max '
              'within this protein. Per substitution: ln p(alt)/p(WT). '
              '${VariantEvidence.esmStrong.toStringAsFixed(1).replaceFirst('-', '−')} '
              'is the strong-effect line published for ESM-1b scores, shown '
              'here as a reference rather than a calibration.',
        ),
        paragraph(
          'AVI',
          'AlphaGenome Variant Impact. Phred is calibrated genome-wide: 10 is '
              'the top 10% of SNVs, 20 the top 1% and 30 the top 0.1%. It '
              'integrates splicing, expression, chromatin, conservation and '
              'coding predictions, AlphaMissense among them, so on a missense '
              'change it overlaps ESM rather than confirming it.',
        ),
        paragraph(
          'AVI contributions',
          'Where included, the three largest signed contributions explain '
              'the exact substitution’s raw AVI score across available genes '
              'and biosamples. They are not percentages or independent evidence. '
              'Details stay available offline.',
        ),
        paragraph(
          'ClinVar',
          !included
              ? 'Not yet included for this gene.'
              : 'NCBI, germline classifications'
                    '${snapshotDate == null ? '' : ', snapshot $snapshotDate'}. '
                    'Single-base records only. Records are submissions, not '
                    'patients. A position without a record is not evidence of '
                    'a benign effect, and submitters may have used '
                    'computational predictions.',
        ),
        Text(
          'Both models predict molecular effects. Neither is a health '
          'assessment.',
          style: body,
        ),
      ],
    );
  }
}
