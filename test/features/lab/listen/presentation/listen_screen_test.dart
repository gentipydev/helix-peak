import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/listen/domain/audio_track.dart';
import 'package:helixpeek/features/lab/listen/domain/dna_score.dart';
import 'package:helixpeek/features/lab/listen/domain/listen_captions.dart';
import 'package:helixpeek/features/lab/listen/presentation/listen_about.dart';
import 'package:helixpeek/features/lab/listen/presentation/listen_player.dart';
import 'package:helixpeek/features/lab/listen/presentation/listen_screen.dart';
import 'package:helixpeek/features/lab/presentation/lab_anatomy_view.dart';
import 'package:helixpeek/shared/anatomy/anatomy_scene.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/anatomy/anatomy_tracer.dart';
import 'package:helixpeek/shared/clinvar/sources_note.dart';

import '../../../../support/catalog_api.dart';
import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';
import '../listen_fixtures.dart';

const Size _phone = Size(390, 844);

/// A player that plays nothing and reports only what a test tells it to:
/// so where the ring goes is where a reported position sends it, and time
/// passing with no report must leave it where it is.
final class FakeListenPlayer implements ListenPlayer {
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();

  final List<ListenSource> loaded = <ListenSource>[];
  final List<Duration> seeks = <Duration>[];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;

  /// What the player says about where it is.
  void report(Duration position) => _positions.add(position);

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Future<void> load(ListenSource source) async => loaded.add(source);

  @override
  Future<void> play() async {
    plays++;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    // A player that has seeked says so the next time it reports.
    _positions.add(position);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _positions.close();
    await _playing.close();
  }
}

Future<FakeListenPlayer> _host(
  WidgetTester tester,
  ProteinTarget target, {
  bool withTrack = true,
  TrackState state = TrackState.ready,
  bool reduced = true,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final FakeListenPlayer player = FakeListenPlayer();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: MediaQuery(
        data: MediaQueryData(size: _phone, disableAnimations: reduced),
        child: ListenScreen(
          key: ValueKey<String>(target.slug),
          target: target,
          record: recordOf(target),
          track: withTrack ? audioOf(target) : null,
          audioState: state,
          player: () => player,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return player;
}

/// The player reports [at], and the screen has drawn what that means. A
/// position arrives as a stream event, which a test frame can take after it
/// has built; the second pump draws it, as the next frame would.
Future<void> _hear(
  WidgetTester tester,
  FakeListenPlayer player,
  Duration at,
) async {
  player.report(at);
  await tester.pump();
  await tester.pump();
}

LabAnatomyView _canvas(WidgetTester tester) => tester.widget<LabAnatomyView>(
  find.byKey(const ValueKey<String>('listen-canvas')),
);

String _caption(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey<String>('listen-caption')))
    .data!;

AnatomyStage _stage(ProteinTarget target, StageKind kind) =>
    AnatomyModel.derive(
      recordOf(target),
      chain: target.chain,
    ).stages.firstWhere((AnatomyStage s) => s.kind == kind);

Future<void> _choose(WidgetTester tester, String mode) async {
  await tester.tap(find.text(mode));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('the protein', () {
    testWidgets(
      'opens on its own sound, handed to the player as it is stored',
      (WidgetTester tester) async {
        final FakeListenPlayer player = await _host(
          tester,
          TestCatalog.insulin,
        );
        expect(player.loaded, hasLength(1));
        expect(player.loaded.single.name, 'insulin.m4a');
        expect(player.loaded.single.bytes, audioOf(TestCatalog.insulin).audio);
        expect(_canvas(tester).scene.from.kind, StageKind.protein);
      },
    );

    testWidgets('the ring goes where the player says, and nowhere else', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      final AnatomyStage protein = _stage(
        TestCatalog.insulin,
        StageKind.protein,
      );

      await _hear(tester, player, const Duration(milliseconds: 380));
      expect(_canvas(tester).tracer, Tracer(protein.positionAt(3)));

      // Playing, with no word from the player: the ring does not move on its
      // own. Only a reported position moves it.
      await tester.tap(find.byKey(const ValueKey<String>('listen-play')));
      await tester.pump(const Duration(seconds: 5));
      expect(_canvas(tester).tracer, Tracer(protein.positionAt(3)));

      await _hear(tester, player, const Duration(milliseconds: 5100));
      expect(_canvas(tester).tracer, Tracer(protein.positionAt(40)));

      await _hear(tester, player, Duration.zero);
      expect(_canvas(tester).tracer, Tracer(protein.positionAt(0)));
    });

    testWidgets('the caption says the note it is on', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      await _hear(tester, player, const Duration(milliseconds: 30 * 125 + 60));
      expect(
        _caption(tester),
        ListenCaptions.residue(audioOf(TestCatalog.insulin), 30),
      );
      expect(_caption(tester), startsWith('Cys31'));
    });

    testWidgets('play and pause go to the player, and the button follows it', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      expect(find.byTooltip('Play'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('listen-play')));
      await tester.pump();
      expect(player.plays, 1);
      expect(find.byTooltip('Pause'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('listen-play')));
      await tester.pump();
      expect(player.pauses, 1);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('a tap on a residue plays from its note', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      final AnatomyScene scene = _canvas(tester).scene;
      final Offset origin = tester.getTopLeft(
        find.byKey(const ValueKey<String>('listen-canvas')),
      );
      await tester.tapAt(origin + scene.fromLayout.centreOf(30));
      await tester.pump();
      expect(player.seeks.last, const Duration(milliseconds: 30 * 125));
      expect(
        _canvas(tester).tracer,
        Tracer(_stage(TestCatalog.insulin, StageKind.protein).positionAt(30)),
      );
    });

    testWidgets('the step buttons move a note at a time, from the player', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      await tester.tap(find.byKey(const ValueKey<String>('listen-next')));
      await tester.pump();
      expect(player.seeks.last, const Duration(milliseconds: 125));
      await tester.tap(find.byKey(const ValueKey<String>('listen-next')));
      await tester.pump();
      expect(player.seeks.last, const Duration(milliseconds: 250));
      expect(_caption(tester), startsWith('Leu3'));
      await tester.tap(find.byKey(const ValueKey<String>('listen-previous')));
      await tester.pump();
      expect(player.seeks.last, const Duration(milliseconds: 125));
      await tester.tap(find.byKey(const ValueKey<String>('listen-restart')));
      await tester.pump();
      expect(player.seeks.last, Duration.zero);
    });

    testWidgets('a long page keeps the note sounding on screen', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(
        tester,
        TestCatalog.dystrophin,
      );
      final AudioTrack track = audioOf(TestCatalog.dystrophin);
      await _hear(tester, player, Duration(milliseconds: track.onsetMs[3600]));
      final ScrollableState scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      final double offset = scroll.position.pixels;
      expect(offset, greaterThan(0));
      final double y = _canvas(tester).scene.fromLayout.centreOf(3600).dy;
      expect(y, greaterThanOrEqualTo(offset));
      expect(y, lessThanOrEqualTo(offset + scroll.position.viewportDimension));
    });
  });

  group('DNA mode', () {
    testWidgets('the gene: chords and a rustle, over the gene page', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      await _choose(tester, 'Gene');
      expect(player.loaded.last.name, 'insulin-gene.wav');
      expect(String.fromCharCodes(player.loaded.last.bytes, 0, 4), 'RIFF');
      expect(_canvas(tester).scene.from.kind, StageKind.gene);

      final DnaScore gene = DnaScore.of(
        AnatomyModel.derive(
          recordOf(TestCatalog.insulin),
          chain: TestCatalog.insulin.chain,
        ),
        spliced: false,
      );
      final int intron = gene.steps.indexWhere(
        (DnaStep s) => s.kind == DnaStepKind.intron,
      );
      await _hear(
        tester,
        player,
        Duration(milliseconds: gene.onsetMs[intron] + 1),
      );
      expect(_canvas(tester).tracer, Tracer(gene.steps[intron].position));
      expect(_caption(tester), startsWith('intron 2 · '));

      await _hear(tester, player, Duration.zero);
      expect(_caption(tester), 'codon 1 · ATG · Met1 · A3 E4 G5');
    });

    testWidgets('a tap on a codon’s middle base plays from that codon', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      await _choose(tester, 'Gene');
      final DnaScore gene = DnaScore.of(
        AnatomyModel.derive(
          recordOf(TestCatalog.insulin),
          chain: TestCatalog.insulin.chain,
        ),
        spliced: false,
      );
      final AnatomyScene scene = _canvas(tester).scene;
      final int cell = scene.from.cellAt(gene.steps[2].positions[1]);
      final Offset origin = tester.getTopLeft(
        find.byKey(const ValueKey<String>('listen-canvas')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('listen-canvas')),
      );
      await tester.tapAt(origin + scene.fromLayout.centreOf(cell));
      await tester.pump();
      expect(player.seeks.last, Duration(milliseconds: gene.onsetMs[2]));
    });

    testWidgets('splicing plays the walk’s own turn of the page', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(
        tester,
        TestCatalog.insulin,
        reduced: false,
      );
      await _choose(tester, 'Gene');
      await _choose(tester, 'mRNA');
      expect(player.loaded.last.name, 'insulin-mrna.wav');
      final AnatomyScene splicing = _canvas(tester).scene;
      expect(splicing.isTransition, isTrue);
      expect(splicing.from.kind, StageKind.gene);
      expect(splicing.to.kind, StageKind.mrna);
      await tester.pumpAndSettle();
      final AnatomyScene rest = _canvas(tester).scene;
      expect(rest.isTransition, isFalse);
      expect(rest.from.kind, StageKind.mrna);
    });

    testWidgets('positions from the piece before are not heard', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      await _hear(tester, player, const Duration(milliseconds: 5100));
      await _choose(tester, 'mRNA');
      // A new piece starts on its first note.
      expect(_caption(tester), startsWith('codon 1 · AUG'));
    });
  });

  group('without the protein’s own track', () {
    testWidgets('its gene still plays, and the screen says why', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(
        tester,
        TestCatalog.insulin,
        withTrack: false,
        state: TrackState.absent,
      );
      expect(player.loaded.single.name, 'insulin-gene.wav');
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('listen-unavailable')),
            )
            .data,
        'The protein’s own sound is not published yet. Its gene can be heard.',
      );
      final SegmentedButton<ListenMode> modes = tester
          .widget<SegmentedButton<ListenMode>>(
            find.byKey(const ValueKey<String>('listen-modes')),
          );
      expect(modes.selected, <ListenMode>{ListenMode.gene});
      expect(
        modes.segments
            .firstWhere(
              (ButtonSegment<ListenMode> s) => s.value == ListenMode.protein,
            )
            .enabled,
        isFalse,
      );
    });

    test('each state in its own words', () {
      expect(
        ListenScreen.unavailable(TrackState.pending, null),
        'The protein’s own sound is on its way.',
      );
      expect(
        ListenScreen.unavailable(TrackState.refused, 'too long'),
        'The protein’s own sound is not published: too long.',
      );
    });
  });

  group('for a reader who cannot hear it', () {
    testWidgets('every control is a labelled target a screen reader reaches', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _host(tester, TestCatalog.insulin);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      for (final String control in <String>[
        'Play',
        'Previous note',
        'Next note',
        'From the start',
        'About this sound',
      ]) {
        expect(
          tester.getSemantics(find.byTooltip(control)),
          isSemantics(tooltip: control, isButton: true, hasTapAction: true),
          reason: control,
        );
      }
      for (final String mode in <String>['Protein', 'Gene', 'mRNA']) {
        expect(find.bySemanticsLabel(mode), findsOneWidget, reason: mode);
      }
      expect(
        tester.getSemantics(find.bySemanticsLabel('Position')),
        isSemantics(
          value: '0:00 of 0:13',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('The piece in words')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('what the sound maps is announced as the piece is shown', (
      WidgetTester tester,
    ) async {
      final List<Map<Object?, Object?>> said = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            Object? message,
          ) async {
            said.add(message! as Map<Object?, Object?>);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await _host(tester, TestCatalog.insulin);
      String announced() => <String>[
        for (final Map<Object?, Object?> m in said)
          if (m['type'] == 'announce')
            (m['data']! as Map<Object?, Object?>)['message']! as String,
      ].join('\n');
      expect(
        announced(),
        contains(ListenCaptions.mapping(audioOf(TestCatalog.insulin))),
      );
      await _choose(tester, 'Gene');
      expect(announced(), contains(ListenCaptions.dnaMapping(spliced: false)));
    });

    testWidgets('a note stood still on is said; one playing past is not', (
      WidgetTester tester,
    ) async {
      final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
      Semantics live() => tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey<String>('listen-caption')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(live().properties.liveRegion, isTrue);
      await tester.tap(find.byKey(const ValueKey<String>('listen-play')));
      await tester.pump();
      expect(live().properties.liveRegion, isFalse);
      await _hear(tester, player, const Duration(milliseconds: 250));
      expect(live().properties.liveRegion, isFalse);
    });

    testWidgets('the piece is there to read, in words', (
      WidgetTester tester,
    ) async {
      await _host(tester, TestCatalog.insulin);
      await tester.tap(find.byKey(const ValueKey<String>('listen-words')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('listen-words-sheet')),
        findsOneWidget,
      );
      expect(
        find.text(ListenCaptions.mapping(audioOf(TestCatalog.insulin))),
        findsOneWidget,
      );
      for (final String line in ListenCaptions.describe(
        audioOf(TestCatalog.insulin),
        TestCatalog.insulin,
      )) {
        expect(find.text(line), findsOneWidget);
      }
    });

    testWidgets(
      'the about sheet says the mapping is arbitrary, channel by channel',
      (WidgetTester tester) async {
        await _host(tester, TestCatalog.insulin);
        await tester.tap(find.byTooltip('About this sound'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('listen-about-statement')),
          findsOneWidget,
        );
        expect(
          ListenAbout.statement,
          contains(
            'an arbitrary mapping chosen for teaching, not a measurement',
          ),
        );
        for (final String channel in <String>[
          'Pitch',
          'Timbre',
          'Loudness',
          'Tick',
          'DNA mode',
          'Tempo',
        ]) {
          expect(
            find.textContaining(channel, findRichText: true),
            findsWidgets,
            reason: channel,
          );
        }
        final String sheet = ListenAbout.channels(audioOf(TestCatalog.insulin))
            .map((SourceEntry e) => '${e.name}: ${e.text}')
            .join('\n');
        expect(sheet, contains('Pitch: Hydropathy'));
        expect(sheet, contains('Timbre: Secondary structure'));
        expect(sheet, contains('(PDB 3I40)'));
        expect(sheet, contains('Loudness: Conservation'));
        expect(
          sheet,
          contains('Tick: A short tick as the note starts: a ClinVar record'),
        );
        expect(sheet, contains('A plays A, C plays C, G plays G'));
        expect(sheet, contains('A note lasts 125 ms, eight a second'));
      },
    );

    testWidgets('without the protein’s track, the sheet describes what plays', (
      WidgetTester tester,
    ) async {
      final String sheet = ListenAbout.channels(null)
          .map((SourceEntry e) => e.name)
          .join(' ');
      expect(sheet, 'DNA mode Tempo');
    });
  });

  testWidgets('leaving lets the player go', (WidgetTester tester) async {
    final FakeListenPlayer player = await _host(tester, TestCatalog.insulin);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(player.disposed, isTrue);
  });

  group('the route', () {
    FetchGene fetch(TrackSource tracks) =>
        FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks)));

    test('reads the track where the row says ready', () async {
      final ListenTrackSource tracks = ListenTrackSource();
      final ListenCubit cubit = ListenCubit(
        withAudio(TestCatalog.glucagon, TrackState.ready),
        tracks,
        fetch(tracks),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final ListenReady ready = cubit.state as ListenReady;
      expect(ready.track!.residues, 180);
      expect(tracks.audioReads, 1);
    });

    test('leaves it, and keeps the record, where it is not', () async {
      final ListenTrackSource tracks = ListenTrackSource();
      for (final TrackState state in <TrackState>[
        TrackState.absent,
        TrackState.pending,
        TrackState.refused,
      ]) {
        final ListenCubit cubit = ListenCubit(
          withAudio(TestCatalog.glucagon, state, reason: 'too long'),
          tracks,
          fetch(tracks),
        );
        await cubit.load();
        final ListenReady ready = cubit.state as ListenReady;
        expect(ready.track, isNull);
        expect(ready.audioState, state);
        expect(ready.record.gene, 'GCG');
        await cubit.close();
      }
      expect(tracks.audioReads, 0);
    });

    testWidgets('opens on the gene where the catalog has no sound for it yet', (
      WidgetTester tester,
    ) async {
      final ListenTrackSource tracks = ListenTrackSource();
      final ProteinCatalogRepository catalog = ProteinCatalogRepository(
        CatalogApi(),
        null,
      );
      addTearDown(catalog.dispose);
      await tester.runAsync(catalog.refresh);
      final FakeListenPlayer player = FakeListenPlayer();
      await tester.binding.setSurfaceSize(_phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: <RepositoryProvider<Object>>[
            RepositoryProvider<TrackSource>.value(value: tracks),
            RepositoryProvider<FetchGene>.value(value: fetch(tracks)),
            RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.analysis,
            home: ListenRoute(
              slug: TestCatalog.insulin.slug,
              player: () => player,
            ),
          ),
        ),
      );
      final Finder unavailable = find.byKey(
        const ValueKey<String>('listen-unavailable'),
      );
      await tester.runAsync(() async {
        for (int i = 0; i < 100 && unavailable.evaluate().isEmpty; i++) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(unavailable, findsOneWidget);
      expect(tracks.audioReads, 0);
    });
  });
}
