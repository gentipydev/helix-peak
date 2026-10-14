import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_screen.dart';
import 'package:helixpeek/shared/widgets/loading_view.dart';

import '../../../support/catalog_api.dart';
import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's header, set as the rest of the app sets its own: the zoom
/// opens over the walk, whose header's row is 44 points, and a header of
/// another height resized the chrome on the way in.

const Size _phone = Size(390, 844);

/// A phone with a status bar, and type turned up to [textScale].
Widget _onPhone(Widget child, {double textScale = 1}) => MediaQuery(
  data: MediaQueryData(
    size: _phone,
    padding: const EdgeInsets.only(top: 59),
    textScaler: TextScaler.linear(textScale),
    disableAnimations: true,
  ),
  child: child,
);

Future<void> _zoom(WidgetTester tester, {double textScale = 1}) async {
  final ProteinTarget target = withLocus(
    TestCatalog.insulin,
    TrackState.ready,
  );
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: _onPhone(
        ZoomScreen(
          key: ValueKey<String>(target.slug),
          target: target,
          track: locusOf(target),
          record: recordOf(target),
        ),
        textScale: textScale,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the zoom\'s header is the walk\'s height', (
    WidgetTester tester,
  ) async {
    await _zoom(tester);
    expect(ZoomScreen.headerHeight, 44);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
      ZoomScreen.headerHeight,
    );
    // Under the status bar, and no taller than that row.
    expect(tester.getSize(find.byType(AppBar)).height, 59 + 44);
    expect(
      find.text(ZoomScreen.titleOf(TestCatalog.insulin)),
      findsOneWidget,
    );
  });

  testWidgets('its title is held where the walk holds its own', (
    WidgetTester tester,
  ) async {
    // The bar does not grow with type, so the title's type is held at the
    // 1.2 the walk's header holds its own at.
    await _zoom(tester, textScale: 2);
    final Finder title = find.text(ZoomScreen.titleOf(TestCatalog.insulin));
    expect(
      MediaQuery.textScalerOf(tester.element(title)).scale(10),
      closeTo(12, 1e-9),
    );
    expect(tester.getSize(find.byType(AppBar)).height, 59 + 44);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wait for a protein\'s row stands under a header', (
    WidgetTester tester,
  ) async {
    // A link to a protein the app holds no row of: the service is asked, and
    // the wait had no header and no safe area, so its label sat under the
    // status bar until one arrived.
    final Completer<Map<String, dynamic>> asked =
        Completer<Map<String, dynamic>>();
    final ProteinCatalogRepository catalog = ProteinCatalogRepository(
      CatalogApi(answer: (_, _) => asked.future),
      null,
    );
    addTearDown(catalog.dispose);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<ProteinCatalogRepository>.value(
        value: catalog,
        child: MaterialApp(
          theme: AppTheme.analysis,
          home: _onPhone(const ZoomRoute(slug: 'nowhere')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('LOADING NOWHERE'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
      ZoomScreen.headerHeight,
    );
    // Its label starts under the header's row, where the zoom's own wait
    // will put it once the row is in.
    expect(tester.getTopLeft(find.byType(LoadingView)).dy, 59 + 44);
  });
}
