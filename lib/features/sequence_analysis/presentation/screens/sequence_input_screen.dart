import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/sequence_validator.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/entities/sequence_input.dart';
import '../bloc/analysis_bloc.dart';
import '../bloc/analysis_event.dart';
import '../widgets/sequence_text_field.dart';

/// Where a sequence is pasted or typed.
class SequenceInputScreen extends StatefulWidget {
  const SequenceInputScreen({super.key});

  @override
  State<SequenceInputScreen> createState() => _SequenceInputScreenState();
}

class _SequenceInputScreenState extends State<SequenceInputScreen> {
  final TextEditingController _controller = TextEditingController();

  /// Shown only after a submit attempt. Validating as the user types would
  /// report "too short" on the way to a perfectly good sequence.
  String? _error;

  /// Live summary of what has been typed. Purely ephemeral view state with no
  /// business meaning, so it stays in the widget rather than going through the
  /// bloc — not everything is bloc state.
  SequenceInput? _preview;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final SequenceValidation validation = SequenceValidator.validate(value);
    setState(() {
      _preview = validation is ValidSequence
          ? SequenceInput.fromValidated(validation)
          : null;
      // Clear a stale error as soon as the input changes.
      if (_error != null) {
        _error = null;
      }
    });
  }

  void _onSubmit() {
    final String raw = _controller.text;
    final SequenceValidation validation = SequenceValidator.validate(raw);

    if (validation is InvalidSequence) {
      setState(() => _error = validation.message);
      return;
    }

    // The bloc validates again — it is the authority, and its tests depend on
    // that. This check exists so the failure can be shown inline here rather
    // than by navigating to a results screen only to display an error.
    context.read<AnalysisBloc>().add(AnalysisEvent.requested(raw));
    context.push(RoutePaths.results);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New analysis')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Paste a raw sequence or a FASTA record.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: SequenceTextField(
                    controller: _controller,
                    onChanged: _onChanged,
                    errorText: _error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PreviewCaption(preview: _preview),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Analyse',
                icon: Icons.science_outlined,
                onPressed: _onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live read-out of what the parser makes of the current input.
class _PreviewCaption extends StatelessWidget {
  const _PreviewCaption({required this.preview});

  final SequenceInput? preview;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SequenceInput? input = preview;

    if (input == null) {
      return Text(
        'Awaiting a valid sequence',
        style: theme.textTheme.labelSmall,
      );
    }

    return Row(
      children: <Widget>[
        Icon(
          Icons.check_circle_outline_rounded,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${input.sequenceType.label} · ${input.length} bases'
            '${input.fastaHeader == null ? '' : ' · ${input.fastaHeader}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
