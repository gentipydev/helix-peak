import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/dna_helix.dart';
import '../widgets/protein_analyses_cta.dart';
import '../widgets/wordmark.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The ground every screen this one leads to is on, so it does not change
    // hue under the reader on the way in; and, on it, the helix in its own
    // bases. Put around itself, as every flow puts its own, so the screen is
    // drawn the same wherever it is pumped.
    return Theme(
      data: AppTheme.home,
      child: Scaffold(
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
                ProteinAnalysesCta(
                  label: 'DNA Replication',
                  onPressed: () => context.push(RoutePaths.replication),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
