import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/impact_explanation_repository.dart';
import '../../domain/entities/impact_explanations.dart';

/// Shared by a selected substitution and a ClinVar record's exact allele.
/// Loading begins only when the containing detail opens.
class ImpactExplanationView extends StatefulWidget {
  const ImpactExplanationView({
    required this.request,
    this.repository,
    super.key,
  });
  final ImpactExplanationRequest request;
  final ImpactExplanationRepository? repository;

  @override
  State<ImpactExplanationView> createState() => _ImpactExplanationViewState();
}

class _ImpactExplanationViewState extends State<ImpactExplanationView> {
  ImpactExplanationRepository? _repository;
  Future<GeneImpactExplanations>? _future;
  bool _details = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository =
        widget.repository ??
        context.read<ImpactExplanationRepository?>();
    if (_future == null || !identical(_repository, repository)) {
      _repository = repository;
      _future = _repository?.load(widget.request.track);
    }
  }

  @override
  void didUpdateWidget(ImpactExplanationView old) {
    super.didUpdateWidget(old);
    if (old.request.track != widget.request.track ||
        old.repository != widget.repository) {
      _repository =
          widget.repository ??
          context.read<ImpactExplanationRepository?>();
      _future = _repository?.load(widget.request.track);
    }
    if (old.request.position != widget.request.position ||
        old.request.alt != widget.request.alt ||
        old.request.track != widget.request.track) {
      _details = false;
    }
  }

  Future<void> _openAtlas(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // A device without a browser can still copy the source reference.
    }
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Atlas link copied. Open it in your browser.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final style = theme.textTheme.bodySmall;
    final muted = theme.colorScheme.onSurfaceVariant;
    final linkStyle = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurface,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FutureBuilder<GeneImpactExplanations>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Text(
              'Loading AVI contributions…',
              style: style,
              key: const ValueKey('impact-contributions-loading'),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('AVI contributions unavailable.', style: style),
                TextButton(
                  key: const ValueKey('impact-contributions-retry'),
                  style: linkStyle,
                  onPressed: () {
                    final next = _repository?.load(widget.request.track);
                    setState(() {
                      _future = next;
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final data = snapshot.data!;
          final explanation = data.at(widget.request);
          if (explanation == null) {
            return Text(
              'No exact AVI contributions for this change.',
              style: style,
            );
          }
          return Column(
            key: ValueKey(
              'impact-contributions-${widget.request.position}-${widget.request.alt}',
            ),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(explanation.summary, style: style),
              TextButton.icon(
                key: const ValueKey('impact-contributions-toggle'),
                style: linkStyle,
                onPressed: () => setState(() => _details = !_details),
                icon: Icon(
                  _details ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _details ? 'Hide contributions' : 'Show contributions',
                ),
              ),
              if (_details) ...<Widget>[
                Text(
                  'Largest contributions · ${widget.request.ref} → ${widget.request.alt}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                for (final contribution in explanation.contributions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(text: '${contribution.label}  '),
                          TextSpan(
                            text: _signed(contribution.value),
                            style: const TextStyle(
                              fontFeatures: <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      style: style,
                    ),
                  ),
                Text(
                  'Up to three largest contributions to AVI’s raw score. '
                  'Positive raises the score; negative lowers it. '
                  'These are not percentages or parts of the Phred value. '
                  'The sign does not indicate an increase or decrease in gene activity.',
                  style: style?.copyWith(color: muted),
                ),
                const SizedBox(height: 8),
                Text(
                  'Across available Atlas genes and biosamples; '
                  'not specific to the selected gene or one tissue.',
                  style: style?.copyWith(color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  'AlphaGenome Atlas · saved ${data.generatedAt.substring(0, 10)}',
                  style: style?.copyWith(color: muted),
                ),
                TextButton.icon(
                  key: const ValueKey('impact-contributions-atlas'),
                  style: linkStyle,
                  onPressed: () => _openAtlas(data.atlasUrl(widget.request)),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View this change in Atlas'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _signed(double value) {
    final magnitude = value.abs() < 0.0001
        ? value.abs().toStringAsExponential(2)
        : value.abs().toStringAsFixed(4);
    return '${value < 0 ? '−' : '+'}$magnitude';
  }
}
