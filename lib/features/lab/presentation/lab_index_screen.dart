import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';

/// One flow the lab offers, as its index lists it.
@immutable
final class LabFeature {
  const LabFeature({
    required this.title,
    required this.summary,
    required this.path,
    this.subject,
  });

  /// The name on the row.
  final String title;

  /// One line under it: what the flow lets a reader do.
  final String summary;

  /// Where the row goes, under `/lab`.
  final String path;

  /// What this flow is fixed to, where it does not ask the reader to pick a
  /// protein: a gene for the story, an assembly for oxygen, the day for the
  /// daily challenge. Null for every flow that picks.
  final String? subject;
}

/// `/lab`: the flows the lab holds, one row each, in the order they arrived.
class LabIndexScreen extends StatelessWidget {
  const LabIndexScreen({required this.features, super.key});

  final List<LabFeature> features;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lab')),
      body: SafeArea(
        child: features.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Text(
                    'Nothing in the lab yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: features.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(indent: AppSpacing.screenPadding),
                itemBuilder: (BuildContext context, int index) {
                  final LabFeature feature = features[index];
                  return ListTile(
                    minTileHeight: 64,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    title: Text(feature.title),
                    subtitle: Text(feature.summary),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (feature.subject case final String gene)
                          Text(
                            gene,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => context.push(feature.path),
                  );
                },
              ),
      ),
    );
  }
}
