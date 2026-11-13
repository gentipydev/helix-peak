import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_spacing.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/gene_layout.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_facts.dart';
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/band_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/dna_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/gene_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_card.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_screen.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';
import 'features/zoom/catalogue_fixtures.dart';

/// The census's check of the zoom, the app's side: every protein the search
/// offers, as the backend's census baked its `locus` track and wrote a
/// record for it (`pipeline/locus/survey.py --gff`), staged at rest at every
/// stop on two phones, a 390×844 and the 375×667 floor, without rasterising.
///
///   `ZOOM_CATALOGUE=<the survey's --out> flutter test test/zoom_catalogue_check.dart`
///
/// For each protein: its track parses; its path, facts, depth and every
/// scene are made, and every stop is painted, into a picture never
/// rasterised; its organ has an anatomy and its cell a shape; its
/// chromosome a territory and a length; its gene's mark is on the band's
/// strip; its gene's exons show whole at its stop, on the canvas; and, on
/// the canvas its own card leaves it (the card grows to its tallest stop's
/// words, the canvas giving way), at every stop every name's plate is
/// wholly on the canvas, clear of
/// every other plate and of the scale bar, no name round a shape cut short
/// by an ellipsis (a quiet name with no room is left out, as the painter
/// leaves it, and counted). The body, organ, tissue and cell are staged once for every
/// protein that draws them alike (organ, cell, the cell it lands in, its
/// words in the cell, its secretome, the tissues lit, the canvas); the
/// nucleus and below for every protein. Writes `<dir>/app_check.json` with
/// the counts and every failure, and fails on any.
void main() {
  final String directory = Platform.environment['ZOOM_CATALOGUE'] ?? '';
  setUpAll(loadAppFonts);

  testWidgets(
    'every protein the search offers zooms, at every stop, on two phones',
    (WidgetTester tester) async {
      final Directory loci = Directory('$directory/locus');
      final List<File> files =
          loci
              .listSync()
              .whereType<File>()
              .where((File f) => f.path.endsWith('_locus.json'))
              .toList()
            ..sort((File a, File b) => a.path.compareTo(b.path));
      final List<_Protein> proteins = <_Protein>[];
      final List<Map<String, String>> failures = <Map<String, String>>[];
      final List<String> unrecorded = <String>[];
      for (final File file in files) {
        final String slug = file.uri.pathSegments.last.replaceFirst(
          '_locus.json',
          '',
        );
        try {
          final (ProteinTarget, LocusTrack, GeneRecord)? read = catalogued(
            directory,
            slug,
          );
          if (read == null) {
            unrecorded.add(slug);
            continue;
          }
          proteins.add(_Protein(slug, read.$1, read.$2, read.$3));
        } on Object catch (e) {
          failures.add(<String, String>{'slug': slug, 'what': 'read: $e'});
        }
      }

      final Map<String, Object> phones = <String, Object>{};
      final Map<String, int> stagings = <String, int>{};
      final Map<String, double> leastCanvas = <String, double>{};
      final Map<String, String> shortest = <String, String>{};
      int elided = 0;
      final Set<String> seen = <String>{};
      final List<int> plates = <int>[0, 0, 0, 0];
      for (final Size phone in const <Size>[Size(390, 844), Size(375, 667)]) {
        final String at = '${phone.width.toInt()}x${phone.height.toInt()}';
        // The canvas the screen gives a protein: the one it gives the first,
        // less what its own card takes beyond the first's.
        final _Protein first = proteins.first;
        await tester.binding.setSurfaceSize(phone);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.analysis,
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: MediaQueryData(size: phone, disableAnimations: true),
              child: ZoomScreen(
                target: first.target,
                track: first.track,
                record: first.record,
              ),
            ),
          ),
        );
        await tester.pump();
        final Finder canvasFinder = find.byKey(
          const ValueKey<String>('zoom-canvas'),
        );
        final Size reference = tester.getSize(canvasFinder);
        final BuildContext context = tester.element(canvasFinder);
        final double inner =
            tester.getSize(find.byType(ZoomCard)).width - 2 * AppSpacing.lg;
        final double referenceWords = ZoomCard.wordsHeight(
          context,
          first.facts,
          inner,
        );
        final ZoomInks inks = ZoomInks.of(context);
        final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
        phones[at] = <String, Object>{
          'canvas_of_${first.slug}': '${reference.width} x ${reference.height}',
        };

        for (final _Protein p in proteins) {
          void fail(String stop, String what) => failures.add(<String, String>{
            'slug': p.slug,
            'phone': at,
            'stop': stop,
            'what': what,
          });
          final Size canvas = Size(
            reference.width,
            reference.height +
                referenceWords -
                ZoomCard.wordsHeight(context, p.facts, inner),
          );
          // The card grows to its tallest stop's words, so no line is ever
          // cut; the canvas gives way instead. How far is counted: the
          // curated already go to 395 points under a long cell's story at
          // 375 by 667, and the names' checks below are what must hold.
          final double least = leastCanvas[at] ?? double.infinity;
          if (canvas.height < least) {
            leastCanvas[at] = canvas.height;
            shortest[at] = p.slug;
          }
          final ZoomStage stage;
          try {
            stage = ZoomStage(ZoomSubject(track: p.track, record: p.record));
          } on Object catch (e) {
            fail('stage', '$e');
            continue;
          }
          final String drawsAlike = <Object?>[
            at,
            canvas.height.round(),
            p.path.tissue,
            p.path.cellType,
            p.path.landsIn?.cell,
            p.inCell.main.join('|'),
            p.inCell.additional.join('|'),
            p.track.secretome,
            (p.track.tissue.specific.map(((String, double) t) => t.$1).toList()
                  ..sort())
                .join('|'),
          ].join('·');
          final bool upper = seen.add(drawsAlike);
          for (final ZoomStop stop in ZoomStop.values) {
            if (stop.index <= ZoomStop.cell.index && !upper) {
              continue;
            }
            stagings[stop.name] = (stagings[stop.name] ?? 0) + 1;
            try {
              elided += _staged(stage, stop, canvas, inks, labels, plates, (
                String what,
              ) {
                fail(stop.name, what);
              });
            } on Object catch (e) {
              fail(stop.name, 'threw: $e');
            }
          }
          try {
            _gene(stage, canvas, inks, fail);
          } on Object catch (e) {
            fail('gene', 'threw: $e');
          }
          if (phone.width == 390) {
            if (p.path.tissue == null || tissueAnatomy[p.path.tissue] == null) {
              fail('organ', 'no anatomy for ${p.path.tissue}');
            }
            archetypeOf(p.path);
            if (!territoryRadius.containsKey(p.track.chromosome) ||
                !chromosomeMegabases.containsKey(p.track.chromosome)) {
              fail('nucleus', 'no territory for ${p.track.chromosome}');
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.binding.setSurfaceSize(null);

      final Map<String, Object> found = <String, Object>{
        'proteins': files.length,
        'checked': proteins.length,
        'unrecorded': unrecorded,
        'phones': phones,
        'stagings': stagings,
        'drawn_alike_upper_stops': seen.length,
        'least_canvas_height': leastCanvas,
        'least_canvas_of': shortest,
        'plates_checked': plates[0],
        'plates_round_a_shape': plates[1],
        'plates_set_untracked': plates[2],
        'quiet_names_left_out': plates[3],
        'elided_plates': elided,
        'failures': failures.length,
        'failure_list': failures,
      };
      File('$directory/app_check.json')
          .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(found));
      expect(failures, isEmpty, reason: '${failures.take(20).toList()}');
      expect(elided, 0);
    },
    skip: directory.isEmpty,
    timeout: Timeout.none,
  );
}

/// One protein of the census, read.
final class _Protein {
  _Protein(this.slug, this.target, this.track, this.record)
    : path = ZoomPath.of(track) {
    facts = ZoomFacts(track: track, path: path, record: record);
    inCell = readingInCell(track.subcellular, path);
  }

  final String slug;
  final ProteinTarget target;
  final LocusTrack track;
  final GeneRecord record;
  final ZoomPath path;
  late final ZoomFacts facts;
  late final SubcellularReading inCell;
}

/// Stages [stop] at rest on [canvas] and lays every name's plate out as the
/// painter does; says what is wrong through [fail]. Returns how many names
/// round a shape lost a line to the ellipsis.
int _staged(
  ZoomStage stage,
  ZoomStop stop,
  Size canvas,
  ZoomInks inks,
  TextStyle labels,
  List<int> counted,
  void Function(String) fail,
) {
  final double d = stage.depth.depthOf(stop);
  final ZoomStaging staging = stage.stage(d, canvas, inks);
  final Map<String, Rect> rows = rowPlates(
    staging.callouts,
    labels,
    inks,
    canvas,
  );
  final Map<String, RingPlate> rings = stage.ringsAt(
    d,
    canvas,
    inks,
    labels,
    staging.callouts,
  );
  final List<Rect> placed = <Rect>[
    ...rows.values,
    for (final RingPlate r in rings.values) r.plate,
  ];
  final (double pixels, String label) = scaleBarAt(stage.depth, d, canvas);
  final TextPainter measure = TextPainter(
    text: TextSpan(text: label, style: labels),
    textDirection: TextDirection.ltr,
  )..layout();
  final Rect bar = scaleBarBox(pixels, measure.size, canvas);
  measure.dispose();
  final List<(ZoomCallout, Rect)> plates = <(ZoomCallout, Rect)>[];
  int elided = 0;
  // A quiet name with no room at rest is left out, as the painter leaves it.
  final Set<String> crowded = stage.crowdedAt(d, canvas, inks, labels);
  for (final ZoomCallout c in staging.callouts) {
    if (crowded.contains(c.key)) {
      counted[3]++;
      continue;
    }
    final RingPlate? ring = rings[c.key];
    final Rect plate;
    if (rows[c.key] != null || ring != null) {
      plate = rows[c.key] ?? ring!.plate;
      if (ring != null &&
          calloutElided(c, labels, inks, canvas, wrapped: ring.wrapped)) {
        elided++;
        fail('${c.text} cut short');
      }
      if (ring != null) {
        // Set untracked to keep to two lines (`calloutText`).
        final TextPainter text = calloutText(
          c,
          labels,
          inks,
          canvas,
          wrapped: ring.wrapped,
        );
        if ((text.text! as TextSpan).style?.letterSpacing == 0) {
          counted[2]++;
        }
        text.dispose();
      }
    } else {
      final TextPainter text = calloutText(c, labels, inks, canvas);
      plate = calloutPlate(
        stage,
        d,
        c,
        text.size,
        canvas,
        placed,
        inks,
        labels,
      );
      text.dispose();
      placed.add(plate);
    }
    plates.add((c, plate));
  }
  // Painted too, into a picture never rasterised: every scene's paint, and
  // the names, the scale bar and what moves at rest a moment after arrival.
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas picture = Canvas(recorder);
  ZoomPainter(
    stage: stage,
    at: () => d,
    inks: inks,
    labels: labels,
  ).paint(picture, canvas);
  ZoomOverlayPainter(
    stage: stage,
    at: () => d,
    inks: inks,
    labels: labels,
    caption: labels,
    credit: 'credit',
    clock: () => 0.5,
    dwell: () => 0.5,
  ).paint(picture, canvas);
  recorder.endRecording().dispose();
  for (int i = 0; i < plates.length; i++) {
    final (ZoomCallout c, Rect plate) = plates[i];
    // A name fading out at rest is no longer read, and a stop's own names
    // are all up.
    if (c.opacity < 0.5) {
      continue;
    }
    counted[0]++;
    if (c.ring != null) {
      counted[1]++;
    }
    if (plate.left < -0.5 ||
        plate.top < -0.5 ||
        plate.right > canvas.width + 0.5 ||
        plate.bottom > canvas.height + 0.5) {
      fail('${c.text} off the canvas at $plate');
    }
    if (plate.overlaps(bar)) {
      fail('${c.text} on the scale bar');
    }
    for (int j = 0; j < i; j++) {
      final (ZoomCallout other, Rect o) = plates[j];
      if (other.opacity >= 0.5 && plate.overlaps(o)) {
        fail('${c.text} over ${other.text}');
      }
    }
  }
  return elided;
}

/// The gene on the band's strip, and its exons at its own stop.
void _gene(
  ZoomStage stage,
  Size canvas,
  ZoomInks inks,
  void Function(String stop, String what) fail,
) {
  final LocusTrack track = stage.subject.track;
  final double band = stage.depth.depthOf(ZoomStop.band);
  for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
    band,
    canvas,
    inks,
  )) {
    if (scene is BandScene) {
      final double a = scene.stripX(frame, track.spanStart.toDouble());
      final double b = scene.stripX(frame, track.spanEnd + 1);
      final double middle = (a + b) / 2;
      if (middle < 0 || middle > canvas.width) {
        fail('band', 'the gene’s mark is off the strip at $middle');
      }
    }
  }
  final double gene = stage.depth.depthOf(ZoomStop.gene);
  final List<GenePiece> exons = <GenePiece>[
    for (final GenePiece piece in stage.subject.layout.pieces)
      if (piece.kind != GenePieceKind.intron) piece,
  ];
  if (exons.isEmpty) {
    fail('gene', 'no exon');
  }
  for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
    gene,
    canvas,
    inks,
  )) {
    if (scene is GeneScene &&
        !exons.any((GenePiece piece) {
          final double a = scene.screenX(frame, piece.start);
          final double b = scene.screenX(frame, piece.end);
          return (a < b ? b : a) >= 0 && (a < b ? a : b) <= canvas.width;
        })) {
      fail('gene', 'no exon on the canvas');
    }
    if (scene is DnaScene && scene.exonsShown(frame) < 0.999) {
      fail('gene', 'its exons are not whole: ${scene.exonsShown(frame)}');
    }
  }
}
