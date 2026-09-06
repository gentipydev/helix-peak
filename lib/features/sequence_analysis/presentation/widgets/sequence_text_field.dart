import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// The sequence entry field.
///
/// Monospace, multiline, and FASTA-aware in its placeholder — showing a real
/// record teaches the accepted format better than a sentence describing it.
class SequenceTextField extends StatelessWidget {
  const SequenceTextField({
    required this.controller,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Rendered inline beneath the field. Validation feedback belongs next to
  /// the input that caused it, not in a snackbar that covers it.
  final String? errorText;

  static const String _placeholder = '>sp|P0DTC2|SPIKE_SARS2 Surface glycoprotein\n'
      'ATGTTTGTTTTTCTTGTTTTATTGCCACTAGTCTCTAGTCAGTGTGTTAAT\n'
      'CTTACAACCAGAACTCAATTACCCCCTGCATACACTAATTCTTTCACACGT';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: null,
      minLines: 8,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      autocorrect: false,
      enableSuggestions: false,
      // Sequence data is case-insensitive but conventionally uppercase, and
      // autocapitalisation of individual bases would fight the user.
      textCapitalization: TextCapitalization.characters,
      style: AppTypography.sequenceBody(theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: _placeholder,
        errorText: errorText,
        alignLabelWithHint: true,
      ),
    );
  }
}
