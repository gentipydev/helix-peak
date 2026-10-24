import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/body_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/nucleus_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_studies.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
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

/// A canvas that keeps the circles drawn on it, filled or stroked.
class _Circles implements Canvas {
  final List<(Offset, PaintingStyle)> circles = <(Offset, PaintingStyle)>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add((c, paint.style));

  // Nothing else is looked at.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

  testWidgets('a nucleus shows the gene’s chromosome’s other copy where the '
      'body has one, and no other where it has none', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    double homologue(ZoomStage stage) =>
        stage
            .stage(stage.depth.depthOf(ZoomStop.nucleus), _canvas, inks)
            .items['territory:homologue']
            ?.$2 ??
        0;
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final NucleusScene nucleus =
          stage.scenes[ZoomStop.nucleus.index] as NucleusScene;
      final bool male = stage.subject.body.name == 'male';
      final bool paired = locusOf(t).chromosome != 'X' || !male;
      expect(nucleus.paired, paired, reason: t.slug);
      expect(homologue(stage), paired ? 1 : 0, reason: t.slug);
    }
    // A gene on the X in a male figure's cell: its second sex chromosome is
    // a Y, which is not the gene's.
    final ProteinTarget testis = TestCatalog.bySlug('izumo1')!;
    final ZoomStage onX = ZoomStage(
      ZoomSubject(
        track: LocusTrack.fromJson(<String, dynamic>{
          ...locusJson(testis),
          'chromosome': 'X',
        }, testis),
        record: recordOf(testis),
      ),
    );
    expect(onX.subject.body.name, 'male');
    expect((onX.scenes[ZoomStop.nucleus.index] as NucleusScene).paired, false);
    expect(homologue(onX), 0);
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
        // The place the body goes into the organ by, and the place the
        // organ's scene samples it: one point of one outline.
        final Offset inBody = staging.items['body:site']!.$1;
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

  testWidgets('the body marks the organ it goes into by its lit shape alone, '
      'with no dot on it, and the ping still spreads from inside it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final BodyScene body = stage.scenes.first as BodyScene;
      final Offset site = BodyScene.place(stage.subject.bodyPart!.site);
      final double d = stage.depth.depthOf(ZoomStop.body);
      const double beats = BodyScene.scanTime + BodyScene.pingTime;
      bool pinged = false;
      for (final double dwell in <double>[
        for (int i = 0; i * 0.05 <= beats; i++) i * 0.05,
        ZoomFrame.settled,
      ]) {
        final ZoomFrame frame = stage
            .frames(d, _canvas, inks, dwell: dwell)
            .firstWhere(((ZoomScene, ZoomFrame) f) => identical(f.$1, body))
            .$2;
        final _Circles canvas = _Circles();
        body.paintAmbient(canvas, frame);
        // No dot: the user's choice of 2026-10-18. The glow behind a lit
        // organ is an oval, and the ping a ring.
        expect(
          canvas.circles.where(
            ((Offset, PaintingStyle) c) => c.$2 == PaintingStyle.fill,
          ),
          isEmpty,
          reason: '${t.slug} at ${dwell}s',
        );
        pinged |= canvas.circles.any(
          ((Offset, PaintingStyle) c) =>
              c.$2 == PaintingStyle.stroke && (c.$1 - site).distance < 1e-9,
        );
      }
      expect(pinged, isTrue, reason: '${t.slug}: no ping');
    }
  });

  testWidgets('at its stop an organ is the size it is, whole in the view', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomSubject subject = stage.subject;
      final ZoomDepth depth = stage.depth;
      // The view is the organ with its margin round it, a tall one's
      // standing on the canvas's height; the salivary gland, its parotid
      // drawn with the ear, the masseter and the submandibular gland round
      // it, the eye, its optic nerve behind it and the recti beside it, and
      // the heart, cut open, its great vessels reaching out either side of
      // it, framed wider than their margin; the kidney, cut open, its names
      // in columns either side of it, framed a little wider than its
      // outline; the skin, a block of it, framed wide enough that its
      // names stand in a column either side of it; the thyroid, seen in
      // place, framed wide enough that its names stand in a row above it
      // and one below it; and the pituitary, cut down its middle among the
      // brain and the bone round it, framed wider still for the same.
      final double upright = ZoomDepth.uprightOf(
        subject.track,
        subject.path,
        subject.anatomy!,
      );
      expect(
        upright,
        inInclusiveRange(
          switch (subject.anatomy!.organ) {
            OrganKind.salivaryGland => ZoomDepth.salivaryUpright,
            OrganKind.eye => ZoomDepth.eyeUpright,
            OrganKind.heart => ZoomDepth.heartUpright,
            OrganKind.skin => ZoomDepth.skinUpright,
            OrganKind.thyroid => ZoomDepth.thyroidUpright,
            OrganKind.pituitary => ZoomDepth.pituitaryUpright,
            _ => 1.0,
          },
          ZoomDepth.phoneAspect,
        ),
        reason: t.slug,
      );
      expect(
        depth.widthOf(ZoomStop.organ),
        closeTo(
          subject.anatomy!.metres * ZoomDepth.organMargin / upright,
          1e-12,
        ),
        reason: t.slug,
      );
      // And the place its tissue is sampled is on the canvas, clear of its
      // edges.
      final Offset site = stage
          .stage(depth.depthOf(ZoomStop.organ), _canvas, inks)
          .items['organ:target']!
          .$1;
      expect(
        (Offset.zero & _canvas).deflate(8).contains(site),
        isTrue,
        reason: '${t.slug}: sampled at $site',
      );
    }
  });

  test('every organ the curated proteins reach is drawn as itself, the place '
      'its tissue is sampled inside it', () {
    // The organs drawn from general anatomy or from the brain's own figure
    // are each a drawing of their own; the twenty's others have a study. An
    // organ no study has been made for yet is the body's own outline of it,
    // seen closer, with its plain surface (the user's choice of 2026-10-17,
    // for the placenta, esophagus, thyroid and kidney the third ten reach;
    // the heart and skeletal muscle, the thigh, are drawn from anatomy since
    // 2026-10-22, the kidney, the liver, the stomach and the esophagus
    // since 2026-10-23, and the thyroid, the adrenal, the pituitary and the
    // lymph node since 2026-10-24): never the organ drawn for no tissue at
    // all.
    const Set<OrganKind> drawn = <OrganKind>{
      OrganKind.brain,
      OrganKind.lymphNode,
      OrganKind.vessel,
      OrganKind.skin,
      OrganKind.parathyroid,
      OrganKind.eye,
    };
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomSubject subject = _stage(t).subject;
      final OrganKind kind = subject.anatomy!.organ;
      final OrganArt art = OrganArt.of(subject);
      expect(
        drawn.contains(kind) ||
            OrganStudy.studied.contains(kind) ||
            art.followsBody,
        isTrue,
        reason: '${t.slug}: $kind has no drawing of its own',
      );
      expect(
        art.outline.contains(art.site),
        isTrue,
        reason: '${t.slug}: sampled outside the $kind',
      );
    }
  });
}
