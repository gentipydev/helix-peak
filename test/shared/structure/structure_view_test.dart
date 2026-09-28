import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../support/test_catalog.dart';

void main() {
  test('a structure opens on the model unless it is asked to fold', () {
    // The Lab's screens show the finished fold, as the page did before it
    // folded: only the walk's fold page asks.
    final StructureView view = StructureView(
      viewport: const Size(390, 520),
      target: TestCatalog.bySlug('insulin')!,
    );
    expect(view.folds, isFalse);
  });

  testWidgets('with no 3D renderer, a page that folds says so, as before', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Scaffold(
          body: StructureView(
            viewport: const Size(390, 520),
            target: TestCatalog.bySlug('insulin')!,
            folds: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        'The structure needs 3D rendering, which is not available here.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Hydrophobic collapse'), findsNothing);
  });
}
