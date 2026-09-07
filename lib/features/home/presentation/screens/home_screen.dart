import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/dna_helix.dart';
import '../widgets/wordmark.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: <Widget>[
              const Expanded(child: DnaHelix()),
              const SizedBox(height: AppSpacing.xl),
              const Wordmark(),
              const SizedBox(height: AppSpacing.xxxl),
              PrimaryButton(
                label: 'Analyse a sequence',
                onPressed: () => context.push(RoutePaths.sequenceInput),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
