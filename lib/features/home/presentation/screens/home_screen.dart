import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/dna_helix.dart';
import '../widgets/wordmark.dart';

/// The landing screen.
///
/// Deliberately sparse: the helix, the wordmark, and one way forward. No app
/// bar, no secondary actions, no cards. The animation is asked to carry the
/// screen, and it can only do that if nothing competes with it.
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
              // The helix takes every pixel not claimed by the text and the
              // button, so the composition breathes on a tall phone and still
              // works on a short one.
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
