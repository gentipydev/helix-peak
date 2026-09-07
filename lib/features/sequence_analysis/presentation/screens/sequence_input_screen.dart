import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../bloc/analysis_bloc.dart';
import '../bloc/analysis_event.dart';
import '../widgets/sequence_text_field.dart';

class SequenceInputScreen extends StatefulWidget {
  const SequenceInputScreen({super.key});

  @override
  State<SequenceInputScreen> createState() => _SequenceInputScreenState();
}

class _SequenceInputScreenState extends State<SequenceInputScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<AnalysisBloc>().add(
          AnalysisEvent.requested(_controller.text),
        );
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
                'Paste a sequence to analyse.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: SequenceTextField(
                    controller: _controller,
                    hintText: 'ATGCGTAGCTAGCTAGCTA',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (
                  BuildContext context,
                  TextEditingValue value,
                  Widget? child,
                ) {
                  return PrimaryButton(
                    label: 'Analyse',
                    icon: Icons.science_outlined,
                    onPressed: value.text.trim().isEmpty ? null : _onSubmit,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
