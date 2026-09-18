import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/router/app_router.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';

import '../../features/gene_lookup/anatomy/anatomy_fixture.dart';

/// A home page with a walk pushed over it, on [platform].
Future<void> _pushWalk(WidgetTester tester, TargetPlatform platform) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final ValueNotifier<bool> pushed = ValueNotifier<bool>(false);
  addTearDown(pushed.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis.copyWith(platform: platform),
      home: ValueListenableBuilder<bool>(
        valueListenable: pushed,
        builder: (BuildContext context, bool walking, Widget? _) => Navigator(
          pages: <Page<void>>[
            const MaterialPage<void>(child: Scaffold(body: Text('home'))),
            if (walking)
              walkPage(
                context: context,
                key: const ValueKey<String>('walk'),
                child: AnatomyScreen(
                  target: ProteinCatalog.insulin,
                  record: insulin(),
                ),
              ),
          ],
          onDidRemovePage: (Page<Object?> page) => pushed.value = false,
        ),
      ),
    ),
  );
  pushed.value = true;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'on iOS a drag from the left edge turns back a stage, not the page',
    (WidgetTester tester) async {
      await _pushWalk(tester, TargetPlatform.iOS);
      expect(find.byType(AnatomyScreen), findsOneWidget);
      await tester.dragFrom(const Offset(200, 804), const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(find.text('465'), findsOneWidget);

      // The drag a reader makes to go back a stage, started at the edge.
      await tester.dragFrom(const Offset(4, 600), const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(find.byType(AnatomyScreen), findsOneWidget);
      expect(find.text('1,431'), findsOneWidget);
    },
  );

  testWidgets('elsewhere the walk is an ordinary page', (
    WidgetTester tester,
  ) async {
    await _pushWalk(tester, TargetPlatform.android);
    expect(find.byType(AnatomyScreen), findsOneWidget);
  });
}
