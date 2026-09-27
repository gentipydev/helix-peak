import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/evidence/variant_evidence.dart';
import '../../core/theme/app_typography.dart';

/// One source a note writes about: what it is, in a sentence, and where to
/// read it.
@immutable
final class SourceEntry {
  const SourceEntry({required this.name, required this.text, this.uri});

  /// The lead the paragraph opens with.
  final String name;

  /// What the source is, and what it does and does not say.
  final String text;

  /// Where to read it. A note draws a link only where there is one.
  final Uri? uri;
}

/// Opens a link outside the app; false where nothing could.
typedef SourceOpener = Future<bool> Function(Uri uri);

Future<bool> _openOutside(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// What each source is, and every caveat the walk has to make about them —
/// written once.
///
/// These sentences used to be spread over every sheet: "not a health
/// assessment" five times, what AVI is four, what ESM is seven. Now a sheet's
/// info button explains its own model's scale and nothing else, and this is
/// the one place the rest is said: the overview's footer and the About sheet.
class SourcesNote extends StatelessWidget {
  const SourcesNote({
    this.snapshotDate,
    this.included = true,
    this.sources,
    this.open = _openOutside,
    super.key,
  });

  /// The ClinVar snapshot's date, once one has loaded.
  final String? snapshotDate;

  /// Whether the gene has a ClinVar snapshot at all. One still loading, or
  /// one that failed, is included and simply has no date to give yet: "not
  /// yet included" is a different state and says something else (R9.3).
  final bool included;

  /// The sources to write about, or null for the walk's own four — the models
  /// it draws and the snapshot it quotes, which is what this note has always
  /// been.
  ///
  /// A flow that rests on something else says so with its own list. The
  /// sickle story's chapters each carry the papers their mechanism comes
  /// from, since a claim and the place it is answered for belong on the same
  /// screen.
  final List<SourceEntry>? sources;

  /// How a source's link is opened. Nothing in the walk's own four has one.
  final SourceOpener open;

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
    Widget paragraph(String name, String text, {Uri? uri}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: '$name  ', style: lead),
                TextSpan(text: text),
              ],
            ),
            style: body,
          ),
          if (uri != null)
            InkWell(
              key: ValueKey<String>('source-link-$name'),
              onTap: () => open(uri),
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  uri.toString(),
                  style: body?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final List<SourceEntry>? given = sources;
    if (given != null) {
      return Column(
        key: const ValueKey<String>('sources-note'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final SourceEntry source in given)
            paragraph(source.name, source.text, uri: source.uri),
        ],
      );
    }
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
