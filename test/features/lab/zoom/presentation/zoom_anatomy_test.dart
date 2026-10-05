import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/body_scene.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/nucleus_scene.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_painter.dart';

import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';
import '../zoom_fixtures.dart';

const Size _canvas = Size(390, 560);

ZoomStage _stage(ProteinTarget t) =>
    ZoomStage(ZoomSubject(track: locusOf(t), record: recordOf(t)));

Future<ZoomInks> _inks(WidgetTester tester) async {
  late ZoomInks inks;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          inks = ZoomInks.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return inks;
}

void main() {
  test('every protein’s organ is found on a figure that has it', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomSubject subject = _stage(t).subject;
      expect(subject.anatomy, isNotNull, reason: t.slug);
      expect(subject.bodyPart, isNotNull, reason: t.slug);
      // A tissue only one body has is shown on that body.
      if (subject.anatomy!.sex != BodySex.either) {
        expect(
          subject.body.name,
          subject.anatomy!.sex == BodySex.male ? 'male' : 'female',
          reason: t.slug,
        );
      }
    }
  });

  test('a nucleus holds the sex chromosomes of the body it is drawn in', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final NucleusScene nucleus =
          stage.scenes[ZoomStop.nucleus.index] as NucleusScene;
      final bool male = stage.subject.body.name == 'male';
      expect(nucleus.kindOf('X', 0), 'X', reason: t.slug);
      expect(nucleus.kindOf('X', 1), male ? 'Y' : 'X', reason: t.slug);
      expect(nucleus.kindOf('7', 1), '7', reason: t.slug);
      // The Y is the smaller territory.
      if (male) {
        expect(
          nucleus.spotOf(nucleus.kindOf('X', 1)),
          lessThan(nucleus.spotOf('X')),
          reason: t.slug,
        );
      }
    }
    // At least one of the twenty is shown on each figure.
    expect(
      <String>{
        for (final ProteinTarget t in TestCatalog.all)
          _stage(t).subject.body.name,
      },
      <String>{'female', 'male'},
    );
  });

  test('the body lights the tissues the Atlas reads the gene raised in, '
      'each by its level against the highest', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomSubject subject = stage.subject;
      final Map<String, double> lit = (stage.scenes.first as BodyScene).lit;
      // What the zoom goes into is always lit.
      expect(lit, contains(subject.anatomy!.uberon), reason: t.slug);
      final List<(String, double)> specific = subject.track.tissue.specific;
      for (final double level in lit.values) {
        expect(level, inInclusiveRange(1e-9, 1.0), reason: t.slug);
      }
      // Nothing is lit that the reading does not name, beyond the organ
      // the path goes to.
      final Set<String> named = <String>{
        subject.anatomy!.uberon,
        for (final (String name, double _) in specific)
          ?tissueAnatomy[ZoomPath.tissueName(name)]?.uberon,
      };
      expect(named.containsAll(lit.keys), isTrue, reason: t.slug);
      if (specific.isNotEmpty) {
        // The highest of them is fully lit, wherever the figure draws it.
        final String? top =
            tissueAnatomy[ZoomPath.tissueName(specific.first.$1)]?.uberon;
        if (subject.body.parts.containsKey(top)) {
          expect(lit[top], 1.0, reason: t.slug);
        }
      }
    }
    // One with several: skeletal muscle highest, the heart and the tongue
    // less.
    final ZoomStage myoglobin = _stage(TestCatalog.myoglobin);
    final Map<String, double> lit = (myoglobin.scenes.first as BodyScene).lit;
    expect(lit[tissueAnatomy['skeletal muscle']!.uberon], 1.0);
    expect(lit[tissueAnatomy['heart muscle']!.uberon], lessThan(1.0));
    expect(lit[tissueAnatomy['heart muscle']!.uberon], greaterThan(0));
  });

  testWidgets('the organ’s own scene takes over the very outline the body '
      'drew: they coincide while both show', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    int followed = 0;
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      if (!(stage.scenes[1] as OrganScene).followsBody) {
        continue;
      }
      followed++;
      final ZoomDepth depth = stage.depth;
      for (final double s in <double>[0.12, 0.2, 0.3]) {
        final ZoomStaging staging = stage.stage(
          depth.depthOf(ZoomStop.body) + s * depth.travelOf(0),
          _canvas,
          inks,
        );
        // The place the body names in the organ, and the place the organ's
        // scene samples it: one point of one outline.
        final Offset inBody = staging.items['callout:body']!.$1;
        final Offset inOrgan = staging.items['organ:target']!.$1;
        expect(
          (inBody - inOrgan).distance,
          lessThan(0.5),
          reason: '${t.slug} at $s of the way',
        );
      }
    }
    // Most organs are the body's own outline.
    expect(followed, greaterThan(TestCatalog.all.length ~/ 2));
  });

  testWidgets('at its stop an organ is the size it is, whole in the view', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomSubject subject = stage.subject;
      final ZoomDepth depth = stage.depth;
      // The view is the organ with its margin round it.
      expect(
        depth.widthOf(ZoomStop.organ),
        closeTo(subject.anatomy!.metres * ZoomDepth.organMargin, 1e-12),
        reason: t.slug,
      );
      // And the place its tissue is sampled is on the canvas, clear of the
      // rail.
      final Offset site = stage
          .stage(depth.depthOf(ZoomStop.organ), _canvas, inks)
          .items['organ:target']!
          .$1;
      expect(
        (Offset.zero & _canvas).deflate(8).contains(site),
        isTrue,
        reason: '${t.slug}: sampled at $site',
      );
      expect(
        site.dx,
        lessThan(_canvas.width - ZoomPainter.railStrip),
        reason: t.slug,
      );
    }
  });
}
