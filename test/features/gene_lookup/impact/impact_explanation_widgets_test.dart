import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/impact_explanation_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/impact_explanations.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_row.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_explanation_view.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';
import '../clinvar/variant_evidence_test.dart' show insulinEvidence;

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

class _Client implements TrackSource {
  _Client(this.data, {this.failures = 0});
  final Map<String, dynamic> data;
  int failures;
  int calls = 0;
  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    calls++;
    expect(slug, 'insulin');
    expect(kind, TrackKind.impactExplanations);
    if (failures-- > 0) {
      throw const ServerApiException(statusCode: 503, detail: 'Unavailable');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(data)));
  }


}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['SHOT_DIR'];
  if (directory != null) {
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!;
    });
    Directory(directory).createSync(recursive: true);
    File('$directory/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }
}

void main() {
  final target = TestCatalog.insulin;
  final track = GeneImpact.fromJson(_json(target.impactAsset), target);
  final request = ImpactExplanationRequest.forAllele(track, 5294, 'C', 'A')!;
  final second = ImpactExplanationRequest.forAllele(track, 5294, 'C', 'T')!;
  final fixture = _json(target.impactExplanationsAsset);
  Finder key(String value) => find.byKey(ValueKey(value));

  setUpAll(() async {
    await loadAppFonts();
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  });

  Future<void> host(
    WidgetTester tester,
    Widget child,
    ImpactExplanationRepository repository, {
    double scale = 1,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<ImpactExplanationRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.analysis,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: const ValueKey('capture'),
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
  }

  testWidgets(
    'loads once through the mock transport and reuses the parsed contract',
    (tester) async {
      final repository = ImpactExplanationRepository(
        _Client(fixture),
      );
      await tester.runAsync(() async {
        final a = repository.load(track);
        final b = repository.load(track);
        expect(identical(a, b), isTrue);
        final data = await a;
        expect(data.at(request)!.contributions.first.feature, 'CACTUS_241_WAY');
      });
      await host(tester, ImpactExplanationView(request: request), repository);
      expect(
        find.textContaining('Conservation · Cactus has the largest'),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed transport offers retry and then recovers', (
    tester,
  ) async {
    final client = _Client(fixture, failures: 1);
    final repository = ImpactExplanationRepository(client);
    await host(tester, ImpactExplanationView(request: request), repository);
    expect(find.text('AVI contributions unavailable.'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(key('impact-contributions-retry'));
      await repository.load(track);
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Conservation · Cactus has the largest'),
      findsOneWidget,
    );
    expect(client.calls, 2);
  });

  testWidgets(
    'changing the allele clears the old detail and preserves its own source link',
    (tester) async {
      final client = _Client(fixture);
      final repository = ImpactExplanationRepository(client);
      await tester.runAsync(() => repository.load(track));
      var current = request;
      late StateSetter update;
      await host(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SingleChildScrollView(
              child: ImpactExplanationView(request: current),
            );
          },
        ),
        repository,
      );
      await tester.tap(key('impact-contributions-toggle'));
      await tester.pumpAndSettle();
      expect(find.text('Largest contributions · C → A'), findsOneWidget);
      update(() => current = second);
      await tester.pumpAndSettle();
      expect(find.text('Largest contributions · C → A'), findsNothing);
      expect(key('impact-contributions-5294-T'), findsOneWidget);
      await tester.tap(key('impact-contributions-toggle'));
      await tester.pumpAndSettle();
      expect(find.text('Largest contributions · C → T'), findsOneWidget);
      String? opened;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          opened = (call.arguments as Map<dynamic, dynamic>)['url'] as String?;
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await tester.ensureVisible(key('impact-contributions-atlas'));
      await tester.tap(key('impact-contributions-atlas'));
      await tester.pumpAndSettle();
      expect(Uri.parse(opened!).queryParameters['q'], 'chr11:2160901:G>A');
      expect(client.calls, 1);
    },
  );

  testWidgets('base rows select only one allele and reset on another base', (
    tester,
  ) async {
    final repository = ImpactExplanationRepository(_Client(fixture));
    await tester.runAsync(() => repository.load(track));
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    var position = 5294;
    late StateSetter update;
    await host(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return ImpactPanel(
            impact: track.at(position)!,
            explanationTrack: track,
            chromosome: track.chromosome,
            address: 'c.71',
            region: 'exon 2',
            note: '',
            tint: Colors.grey,
            controller: controller,
            slide: const AlwaysStoppedAnimation(Offset.zero),
            pinIdentity: true,
            onDismiss: () {},
          );
        },
      ),
      repository,
    );
    expect(find.byType(ImpactExplanationView), findsNothing);
    await tester.ensureVisible(key('impact-explain-A'));
    await tester.tap(key('impact-explain-A'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(key('impact-contributions-5294-A'), findsOneWidget);
    await tester.tap(key('impact-contributions-toggle'));
    await tester.pumpAndSettle();
    await _capture(tester, 'avi-contributions-base-sheet');
    await tester.ensureVisible(key('impact-explain-T'));
    await tester.pumpAndSettle();
    await tester.tap(key('impact-explain-T'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(key('impact-contributions-5294-A'), findsNothing);
    expect(key('impact-contributions-5294-T'), findsOneWidget);
    expect(find.byType(ImpactExplanationView), findsOneWidget);
    update(() => position = 5295);
    await tester.pumpAndSettle();
    expect(find.byType(ImpactExplanationView), findsNothing);
  });

  testWidgets('expanded ClinVar record uses the record allele', (tester) async {
    final evidence = insulinEvidence().firstWhere(
      (e) => e.variant.position == 5294 && e.variant.alt == 'A',
    );
    final repository = ImpactExplanationRepository(_Client(fixture));
    await tester.runAsync(() => repository.load(evidence.explanation!.track));
    await host(
      tester,
      SingleChildScrollView(child: EvidenceDetail(evidence: evidence)),
      repository,
    );
    expect(key('impact-contributions-5294-A'), findsOneWidget);
    expect(key('impact-contributions-5294-T'), findsNothing);
  });

  testWidgets(
    'signed details and source remain readable at large text on a narrow screen',
    (tester) async {
      final modified = _json(target.impactExplanationsAsset);
      (((modified['positions'] as Map<String, dynamic>)['5294']
                  as List<dynamic>)
              .first
          as List<dynamic>)[1] = <dynamic>[
        <dynamic>[0, -0.75],
        <dynamic>[1, 0.25],
      ];
      final repository = ImpactExplanationRepository(_Client(modified));
      await tester.runAsync(() => repository.load(track));
      await host(
        tester,
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ImpactExplanationView(request: request),
          ),
        ),
        repository,
        scale: 2,
        size: const Size(320, 740),
      );
      expect(find.textContaining('lowering the AVI score'), findsOneWidget);
      await tester.tap(key('impact-contributions-toggle'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('impact-contributions-atlas'));
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('not specific to the selected gene'),
        findsOneWidget,
      );
      await _capture(tester, 'avi-contributions-large-text');
    },
  );
}
