import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';

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

  testWidgets('a walk pushed over a page keeps the edge drag for its stages', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis.copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                walkRoute<void>(
                  context,
                  (_) => AnatomyScreen(
                    target: ProteinCatalog.insulin,
                    record: insulin(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 804), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('465'), findsOneWidget);

    // The reader's drag back a stage, started at the edge, is not a pop.
    await tester.dragFrom(const Offset(4, 600), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.byType(AnatomyScreen), findsOneWidget);
    expect(find.text('1,431'), findsOneWidget);
  });

  testWidgets('elsewhere a pushed walk is an ordinary page', (
    WidgetTester tester,
  ) async {
    late Route<void> route;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis.copyWith(platform: TargetPlatform.android),
        home: Builder(
          builder: (BuildContext context) {
            route = walkRoute<void>(context, (_) => const SizedBox());
            return const SizedBox();
          },
        ),
      ),
    );
    expect(route, isA<MaterialPageRoute<void>>());
  });
}
