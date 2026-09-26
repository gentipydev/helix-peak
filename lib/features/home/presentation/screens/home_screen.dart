import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/dna_helix.dart';
import '../widgets/protein_analyses_cta.dart';
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
              ProteinAnalysesCta(
                onPressed: () => context.push(RoutePaths.search),
              ),
              // Only in a build with the lab switched on. Without it the
              // column is exactly what it was.
              if (Env.labEnabled)
                ProteinAnalysesCta(
                  label: 'Lab',
                  onPressed: () => context.push(RoutePaths.lab),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
