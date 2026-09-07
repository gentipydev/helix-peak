import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

class SequenceTextField extends StatelessWidget {
  const SequenceTextField({required this.controller, this.hintText, super.key});

  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return TextField(
      controller: controller,
      maxLines: null,
      minLines: 8,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      style: AppTypography.sequenceBody(theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        alignLabelWithHint: true,
      ),
    );
  }
}
