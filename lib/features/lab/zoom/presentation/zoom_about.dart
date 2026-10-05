import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/clinvar/sources_note.dart';
import '../domain/zoom_facts.dart';

/// The zoom's About sheet: what is drawn and what is data, and every source
/// with its licence, said once here rather than under every stop.
class ZoomAbout extends StatelessWidget {
  const ZoomAbout({required this.facts, super.key});

  final ZoomFacts facts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey<String>('zoom-about-sheet'),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'About this zoom',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SourcesNote(
              sources: <SourceEntry>[
                for (final ZoomSource source in facts.about)
                  SourceEntry(
                    name: source.name,
                    text: source.text,
                    uri: source.uri == null ? null : Uri.parse(source.uri!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
