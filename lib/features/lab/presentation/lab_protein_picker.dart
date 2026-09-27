import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/protein_target.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../gene_lookup/data/repositories/protein_catalog_repository.dart';

/// The catalog as a plain list, for a lab flow to pick its protein from.
///
/// Read from the app's [ProteinCatalogRepository], the same rows the search
/// screen shows, so the lab never keeps a list of its own. A row goes to
/// `[base]/<slug>`.
class LabProteinPicker extends StatelessWidget {
  const LabProteinPicker({
    required this.title,
    required this.base,
    this.lead,
    super.key,
  });

  /// The flow's name, on the app bar.
  final String title;

  /// The flow's route, under which each protein's page sits.
  final String base;

  /// A line above the list saying what picking a protein will do.
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final ProteinCatalogRepository catalog = context
        .read<ProteinCatalogRepository>();
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ValueListenableBuilder<List<ProteinTarget>>(
          valueListenable: catalog.rows,
          builder: (BuildContext context, List<ProteinTarget> rows, _) {
            if (rows.isEmpty) {
              return const LoadingView(label: 'LOADING PROTEINS');
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              itemCount: rows.length + (lead == null ? 0 : 1),
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(indent: AppSpacing.screenPadding),
              itemBuilder: (BuildContext context, int index) {
                if (lead case final String line when index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                    ),
                    child: Text(
                      line,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final ProteinTarget target =
                    rows[index - (lead == null ? 0 : 1)];
                return ListTile(
                  minTileHeight: 56,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  title: Text(target.display),
                  subtitle: Text(target.gene),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('$base/${target.slug}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Resolves a slug to its catalog row, then builds [builder] with it.
///
/// A deep link can arrive before the catalog, or name a protein outside it;
/// both are handled the way the walk's router handles them, by asking the
/// repository for the one protein.
class LabTargetLoader extends StatefulWidget {
  const LabTargetLoader({
    required this.slug,
    required this.builder,
    super.key,
  });

  final String slug;
  final Widget Function(BuildContext context, ProteinTarget target) builder;

  @override
  State<LabTargetLoader> createState() => _LabTargetLoaderState();
}

class _LabTargetLoaderState extends State<LabTargetLoader> {
  ProteinTarget? _target;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _target = context.read<ProteinCatalogRepository>().bySlug(widget.slug);
    if (_target == null) {
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    final ProteinCatalogRepository catalog = context
        .read<ProteinCatalogRepository>();
    try {
      final ProteinTarget target = await catalog.protein(widget.slug);
      if (mounted) {
        setState(() => _target = target);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProteinTarget? target = _target;
    if (target != null) {
      return widget.builder(context, target);
    }
    final Object? error = _error;
    if (error == null) {
      return Scaffold(
        body: LoadingView(label: 'LOADING ${widget.slug.toUpperCase()}'),
      );
    }
    return Scaffold(
      appBar: AppBar(),
      body: ErrorView(
        title: 'Fetch failed',
        message: error is ApiException
            ? error.userMessage
            : const UnknownApiException().userMessage,
        onRetry: () {
          setState(() => _error = null);
          unawaited(_resolve());
        },
      ),
    );
  }
}
