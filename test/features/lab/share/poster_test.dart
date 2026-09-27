import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/gene_query.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/screens/gene_screen.dart';
import 'package:helixpeek/features/lab/share/fold_still.dart';
import 'package:helixpeek/features/lab/share/gene_link.dart';
import 'package:helixpeek/features/lab/share/poster_builder.dart';
import 'package:helixpeek/features/lab/share/share_action.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:image/image.dart' as img;

import '../../../support/catalog_api.dart';
import '../../../support/fixture_track_source.dart';
import '../../../support/test_catalog.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

const Color _foldInk = Color(0xFFFF00FF);

/// A stand-in fold: one flat colour, the size it is asked for.
Future<ui.Image> _flat(int width, int height) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(_foldInk, BlendMode.src);
  return recorder.endRecording().toImage(width, height);
}

img.Color _at(img.Image image, Offset logical, double ratio) =>
    image.getPixel((logical.dx * ratio).round(), (logical.dy * ratio).round());

bool _isFoldInk(img.Color c) => c.r == 255 && c.g == 0 && c.b == 255;

/// Lets the button's real work — rasterising and encoding, which the engine
/// does outside the test's fake clock — run until the sheet is handed a
/// poster, then settles the button.
Future<T> _settle<T>(WidgetTester tester, Completer<T> shared) async {
  for (int i = 0; i < 400 && !shared.isCompleted; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  expect(shared.isCompleted, isTrue, reason: 'the sheet was never called');
  await tester.pump();
  return shared.future;
}

void main() {
  final ProteinTarget insulin = TestCatalog.insulin;
  final AnatomyModel model = AnatomyModel.derive(_gene('ins'));

  test('the link is the app\'s scheme and the walk\'s own path', () {
    expect(geneLink(insulin).toString(), 'helixpeek://open/gene/insulin');
    expect(geneLink(insulin).path, '/gene/insulin');
    expect(
      posterText(insulin),
      'Insulin in Helix Peek: $geneLinkScheme://open/gene/insulin',
    );
  });

  group('trimToContent', () {
    Future<ui.Image> drawn({required bool clear}) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      if (!clear) {
        canvas.drawColor(const Color(0xFF000000), BlendMode.src);
      }
      canvas.drawRect(
        const Rect.fromLTWH(30, 40, 20, 10),
        Paint()..color = _foldInk,
      );
      return recorder.endRecording().toImage(100, 80);
    }

    testWidgets('cuts a transparent margin down to what is drawn', (
      WidgetTester tester,
    ) async {
      final (int, int) size = (await tester.runAsync(() async {
        final ui.Image trimmed = await trimToContent(await drawn(clear: true));
        final (int, int) size = (trimmed.width, trimmed.height);
        trimmed.dispose();
        return size;
      }))!;
      expect(size, (20 + 2 * 8, 10 + 2 * 8));
    });

    testWidgets('leaves an image with nothing transparent as it was', (
      WidgetTester tester,
    ) async {
      final (int, int) size = (await tester.runAsync(() async {
        final ui.Image kept = await trimToContent(await drawn(clear: false));
        final (int, int) size = (kept.width, kept.height);
        kept.dispose();
        return size;
      }))!;
      expect(size, (100, 80));
    });
  });

  group('PosterBuilder', () {
    final PosterBuilder poster = PosterBuilder(
      target: insulin,
      model: model,
      theme: AppTheme.analysis,
    );

    testWidgets('one high-resolution PNG, with the fold where it is given', (
      WidgetTester tester,
    ) async {
      final (Uint8List withFold, Uint8List withoutFold) = (await tester
          .runAsync(() async {
            final Rect box = poster.foldBox;
            final ui.Image fold = await _flat(
              (box.width * poster.pixelRatio).round(),
              (box.height * poster.pixelRatio).round(),
            );
            try {
              return (await poster.build(fold: fold), await poster.build());
            } finally {
              fold.dispose();
            }
          }))!;

      final img.Image a = img.decodePng(withFold)!;
      expect((a.width, a.height), (2160, 2700));
      expect(_isFoldInk(_at(a, poster.foldBox.center, 2)), isTrue);

      // Without a fold, the grid moves up into its place; nothing is left
      // magenta, and the space holds more than the background.
      final img.Image b = img.decodePng(withoutFold)!;
      expect((b.width, b.height), (2160, 2700));
      expect(_isFoldInk(_at(b, poster.foldBox.center, 2)), isFalse);
      final Set<int> inks = <int>{};
      final int y = (poster.foldBox.top + 40).round() * 2;
      for (int x = 0; x < b.width; x += 4) {
        final img.Color c = b.getPixel(x, y);
        inks.add((c.r.toInt() << 16) | (c.g.toInt() << 8) | c.b.toInt());
      }
      expect(inks.length, greaterThan(2), reason: 'the grid is drawn there');
    });

    testWidgets('the same inputs make the same poster', (
      WidgetTester tester,
    ) async {
      final (Uint8List one, Uint8List two) = (await tester.runAsync(
        () async => (await poster.build(), await poster.build()),
      ))!;
      expect(one, two);
    });
  });

  group('SharePosterButton', () {
    Future<Completer<(Uint8List, String, String)>> host(
      WidgetTester tester, {
      required FoldRenderer renderFold,
    }) async {
      final Completer<(Uint8List, String, String)> shared =
          Completer<(Uint8List, String, String)>();
      await tester.pumpWidget(
        RepositoryProvider<TrackSource>.value(
          value: FixtureTrackSource(),
          child: MaterialApp(
            theme: AppTheme.analysis,
            home: Scaffold(
              appBar: AppBar(
                actions: <Widget>[
                  SharePosterButton(
                    target: insulin,
                    model: model,
                    renderFold: renderFold,
                    shareSheet:
                        ({
                          required Uint8List png,
                          required String fileName,
                          required String text,
                          Rect? origin,
                        }) async {
                          shared.complete((png, fileName, text));
                        },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return shared;
    }

    testWidgets('makes the poster, fold and all, and hands it to the sheet', (
      WidgetTester tester,
    ) async {
      final List<(String, int, int)> asked = <(String, int, int)>[];
      final Completer<(Uint8List, String, String)> shared = await host(
        tester,
        renderFold:
            ({
              required ProteinTarget target,
              required TrackSource tracks,
              required AnatomyColors anatomy,
              required int width,
              required int height,
            }) {
              asked.add((target.slug, width, height));
              return _flat(width, height);
            },
      );
      await tester.tap(find.byTooltip('Share a poster'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final (Uint8List png, String name, String text) = await _settle(
        tester,
        shared,
      );

      expect(asked, <(String, int, int)>[('insulin', 3744, 2160)]);
      expect(name, 'insulin-helix-peek.png');
      expect(text, 'Insulin in Helix Peek: helixpeek://open/gene/insulin');
      final img.Image poster = img.decodePng(png)!;
      expect((poster.width, poster.height), (2160, 2700));
      expect(
        _isFoldInk(
          _at(
            poster,
            PosterBuilder(
              target: insulin,
              model: model,
              theme: AppTheme.analysis,
            ).foldBox.center,
            2,
          ),
        ),
        isTrue,
      );
      expect(find.byIcon(Icons.ios_share), findsOneWidget);
    });

    testWidgets('with no fold to draw, still shares the poster', (
      WidgetTester tester,
    ) async {
      final Completer<(Uint8List, String, String)> shared = await host(
        tester,
        renderFold: ({
          required ProteinTarget target,
          required TrackSource tracks,
          required AnatomyColors anatomy,
          required int width,
          required int height,
        }) async => null,
      );
      await tester.tap(find.byTooltip('Share a poster'));
      final (Uint8List png, _, _) = await _settle(tester, shared);
      expect(img.decodePng(png)!.width, 2160);
    });
  });

  testWidgets('the link opens the walk when the platform delivers it', (
    WidgetTester tester,
  ) async {
    final ProteinCatalogRepository catalog = ProteinCatalogRepository(
      CatalogApi(),
      null,
    );
    addTearDown(catalog.dispose);
    await catalog.refresh();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
          RepositoryProvider<FetchGene>.value(value: FetchGene(_Records())),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    expect(find.byType(GeneScreen), findsNothing);
    // What Flutter's embedding sends when the app is opened by the link.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', <String, Object?>{
          'location': geneLink(insulin).toString(),
          'state': null,
        }),
      ),
      (ByteData? _) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GeneScreen), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      '/gene/insulin',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });
}

/// Never answers, so a walk stays on its own loading page: still `GeneScreen`.
class _Records implements GeneRepository {
  @override
  Future<GeneRecord> fetchGene(GeneQuery query) =>
      Completer<GeneRecord>().future;
}
