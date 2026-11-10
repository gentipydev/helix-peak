import 'package:flutter/material.dart';

/// A page of words the ⓘ opens: a title, a lead where the page has one, and
/// its sections, each a heading over one or more paragraphs.
@immutable
final class LmInfo {
  const LmInfo({required this.title, this.lead, required this.sections});

  final String title;

  /// What the stage takes and what it gives, under the title, unheaded.
  final String? lead;
  final List<LmInfoSection> sections;
}

@immutable
final class LmInfoSection {
  const LmInfoSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

/// An [LmInfo] as a bottom sheet: as tall as its words, up to four fifths of
/// the screen, past which it scrolls.
class LmInfoSheet extends StatelessWidget {
  const LmInfoSheet({required this.info, super.key});

  final LmInfo info;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme text = theme.textTheme;
    final String? lead = info.lead;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          key: const ValueKey<String>('peptide-lm-info-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: <Widget>[
            Text(info.title, style: text.titleLarge),
            const SizedBox(height: 22),
            if (lead != null) ...<Widget>[
              // What the stage takes and gives, the line to read first: in
              // the bright ink, over the sections' quiet paragraphs.
              Text(lead, style: text.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
              if (info.sections.isNotEmpty) const SizedBox(height: 20),
            ],
            for (int s = 0; s < info.sections.length; s++)
              Padding(
                // Room under each section but the last, which ends on the
                // list's own padding.
                padding: EdgeInsets.only(bottom: s < info.sections.length - 1 ? 20 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(info.sections[s].title, style: text.titleSmall),
                    const SizedBox(height: 6),
                    for (int i = 0; i < info.sections[s].paragraphs.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 8),
                      Text(info.sections[s].paragraphs[i], style: text.bodyMedium),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
