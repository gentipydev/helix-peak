import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeak/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_layout.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeak/features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import 'package:helixpeak/features/gene_lookup/presentation/screens/gene_screen.dart';
import 'package:helixpeak/features/home/presentation/screens/home_screen.dart';
import 'package:mocktail/mocktail.dart';

// GeneLookupCubit is a final class and cannot be mocked directly, so the screen
// is driven by a real cubit over a stubbed repository.
class _MockGeneRepository extends Mock implements GeneRepository {}

GeneRecord _insulin() {
  final Map<String, dynamic> json = jsonDecode(
    File('assets/mock/gene_ins.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return GeneRecordDto.fromJson(json).toEntity();
}

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(File(path).readAsBytesSync().buffer),
      ),
    );
  }
  await loader.load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary = tester.firstRenderObject(
    find.byType(RepaintBoundary),
  ) as RenderRepaintBoundary;

  // Both of these resolve on the real event loop, which the fake clock inside
  // testWidgets never pumps. Awaited directly they hang until the whole test
  // times out — the file still lands, ten minutes late, and the run is marked
  // failed. runAsync hands them a loop that actually turns.
  final ByteData? bytes = await tester.runAsync<ByteData>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return data!;
  });

  File('${Platform.environment['SHOT_DIR']}/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _swipe(WidgetTester tester, {required bool forward}) async {
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    Offset(forward ? -160 : 160, 0),
  );
  // The gesture's own frame has to land before the clock is advanced —
  // otherwise the controller starts on the frame a timed pump asks for and
  // every mid-transition capture is really a capture of t = 0.
  await tester.pump();
}

/// Taps the square holding a genomic coordinate, by recomputing the layout the
/// painter is using against the box it is actually painted in.
Future<void> _tapBase(
  WidgetTester tester,
  AnatomyModel model, {
  required int stage,
  required int position,
}) async {
  final Finder box = find.byWidgetPredicate(
    (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
  );
  final Rect rect = tester.getRect(box);
  final AnatomyLayout layout = AnatomyLayout.forStage(
    model.stages[stage],
    rect.size,
    rect.size,
  );
  final int cell = model.stages[stage].cellAt(position);
  await tester.tapAt(rect.topLeft + layout.centreOf(cell));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await _loadFont('SpaceGrotesk', <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ]);
    await _loadFont('JetBrainsMono', <String>[
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Medium.ttf',
    ]);
  });

  testWidgets('home screen', (WidgetTester tester) async {
    if ((Platform.environment['SHOT_DIR'] ?? '').isEmpty) {
      markTestSkipped('set SHOT_DIR to capture the screens');
      return;
    }

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await _capture(tester, 'home');
  });

  testWidgets('anatomy screen', (WidgetTester tester) async {
    if ((Platform.environment['SHOT_DIR'] ?? '').isEmpty) {
      markTestSkipped('set SHOT_DIR to capture the screens');
      return;
    }

    final _MockGeneRepository repository = _MockGeneRepository();
    when(
      () => repository.fetchGene(
        accession: any(named: 'accession'),
        gene: any(named: 'gene'),
      ),
    ).thenAnswer((_) async => _insulin());

    final GeneLookupCubit cubit = GeneLookupCubit(FetchGene(repository));
    await cubit.load(ProteinCatalog.insulin.query);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          home: BlocProvider<GeneLookupCubit>.value(
            value: cubit,
            child: const GeneScreen(target: ProteinCatalog.insulin),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AnatomyModel model = AnatomyModel.derive(_insulin());

    // Every stage, plus one frame caught mid-splice — the signature moment is
    // the one thing a still of either end cannot show.
    await _capture(tester, 'anatomy-1-gene');
    await _swipe(tester, forward: true);
    await tester.pump(const Duration(milliseconds: 700));
    await _capture(tester, 'anatomy-1-2-splicing');
    await tester.pumpAndSettle();

    // The reading frame grooving itself open is a second event, after the
    // splice rather than during it, and a still of either end of it shows a
    // grid of bases with nothing happening. This is the one frame that says
    // what the page is about: the triplets parting in a sweep down the block,
    // with the start codon already green and the stop codon not yet red.
    await _swipe(tester, forward: false);
    await tester.pumpAndSettle();
    await _swipe(tester, forward: true);
    // Past the end of the splice, so the groove has been asked to start...
    await tester.pump(const Duration(milliseconds: 1650));
    // ...one frame for its ticker to take its zero...
    await tester.pump();
    // ...and then into the sweep, where the top of the block is open, the
    // middle is parting and the stop codon has not moved yet.
    await tester.pump(const Duration(milliseconds: 320));
    await _capture(tester, 'anatomy-2-mrna-grooving');
    await tester.pumpAndSettle();
    await _capture(tester, 'anatomy-2-mrna');

    // The transcript page is about twice a phone, so a still of its top is half
    // the argument. The other half is the 3' UTR at the bottom, washed back the
    // same way the 5' UTR is at the top.
    await tester.drag(find.byType(AnatomyCanvas), const Offset(0, -420));
    await tester.pumpAndSettle();
    await _capture(tester, 'anatomy-2-mrna-scrolled');
    await tester.drag(find.byType(AnatomyCanvas), const Offset(0, 999));
    await tester.pumpAndSettle();

    // The two squares on this page that answer for themselves. Everything else
    // on it is a base, and a base is not a question anyone has.
    await _tapBase(tester, model, stage: 1, position: 5224);
    await _capture(tester, 'anatomy-frame-start');
    await _tapBase(tester, model, stage: 1, position: 5224);

    // Translation carries two events now — the untranslated ends leaving and
    // the codons folding into residues — so it gets a mid-flight still of its
    // own for the same reason splicing does.
    await _swipe(tester, forward: true);
    await tester.pump(const Duration(milliseconds: 480));
    await _capture(tester, 'anatomy-2-3-translation');
    await tester.pumpAndSettle();
    await _capture(tester, 'anatomy-3-protein');

    // The cleavage carries the whole signal peptide out now, not four squares,
    // so it gets a mid-flight still of its own too.
    await _swipe(tester, forward: true);
    await tester.pump(const Duration(milliseconds: 520));
    await _capture(tester, 'anatomy-3-4-cleavage');
    await tester.pumpAndSettle();
    await _capture(tester, 'anatomy-4-mature');

    // A run selected at the gene stage: everything else steps back.
    for (int i = 0; i < 3; i++) {
      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
    }
    await _tapBase(tester, model, stage: 0, position: 6000);
    await _capture(tester, 'anatomy-run-intron');
    await _tapBase(tester, model, stage: 0, position: 5301);
    await _capture(tester, 'anatomy-run-bchain');
    await _tapBase(tester, model, stage: 0, position: 5301);

    // The split feature, tapped on its smaller half: the 17 bases in exon 2.
    // Both pieces have to light, because the caption says 59.
    await _tapBase(tester, model, stage: 0, position: 5207);
    await _capture(tester, 'anatomy-run-utr5');
    await _tapBase(tester, model, stage: 0, position: 5207);

    for (int i = 0; i < 2; i++) {
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
    }

    // Back to the protein, and trace one residue. Selection lives on the
    // residue stages now, so the trace starts there and the interesting half
    // runs *backwards*: the residue splits into the three bases it was made
    // from and they take their places in the gene.
    await _tapBase(tester, model, stage: 2, position: 5299);
    await _capture(tester, 'anatomy-tracer-protein');

    for (final String name in <String>[
      'anatomy-tracer-mrna',
      'anatomy-tracer-alive',
    ]) {
      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
      await _capture(tester, name);
    }

    // And the ending worth watching: the RR site, consumed by the protease on
    // the next swipe. A cut cell settles where it drifted to, so this wants a
    // residue near the middle of the grid rather than one of the signal
    // peptide's, which all sit in the top rows and drift off the canvas.
    for (int i = 0; i < 2; i++) {
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
    }
    await _tapBase(tester, model, stage: 2, position: 5386);
    await _swipe(tester, forward: true);
    await tester.pumpAndSettle();
    await _capture(tester, 'anatomy-tracer-cut');
  });
}
