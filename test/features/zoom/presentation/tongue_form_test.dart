import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/tongue/tongue_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/tongue/tongue_form.dart';

final TissueAnatomy _anatomy = tissueAnatomy['tongue']!;
// A view the width of the card's tongue with its margin: the form's own
// proportions are the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

TongueForm _form(AnatomyFigure figure) =>
    TongueForm.place(part: figure.parts[_anatomy.uberon]!, view: _view);

Rect _bounds(List<Offset> points) {
  Rect box = Rect.fromLTRB(
    points.first.dx,
    points.first.dy,
    points.first.dx,
    points.first.dy,
  );
  for (final Offset p in points) {
    box = box.expandToInclude(Rect.fromLTRB(p.dx, p.dy, p.dx, p.dy));
  }
  return box;
}

bool _in(List<Offset> polygon, Offset p) => TongueForm.inside(polygon, p);

void main() {
  test('it is a tongue at a person’s size, as the figure is drawn, laid '
      'where the body goes in, over the body’s mouth, or its sliver, on '
      'either figure', () {
    final Rect soft = _bounds(TongueForm.softMm);
    // The tongue at rest, 43 mm across at its margins.
    expect(soft.width, closeTo(43.3, 0.3));
    expect(soft.center.dx, closeTo(0, 1e-9));
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final AnatomyPart part = figure.parts[_anatomy.uberon]!;
      final TongueForm form = _form(figure);
      expect(TongueForm.real, 1);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-12), reason: figure.name);
      expect(
        (form.site - (part.site - part.centre) / _view).distance,
        lessThan(1e-9),
        reason: figure.name,
      );
      expect(form.contains(form.site), isTrue, reason: figure.name);
      expect(
        (form.toMm(form.site) - TongueAnatomy.site).distance,
        lessThan(1e-9),
      );
    }
    // The soft tissue lies over the female figure's mouth; the male's is a
    // sliver at its top.
    expect(_form(AnatomyFigure.female).anchorShift, lessThan(0.5));
    expect(_form(AnatomyFigure.male).anchorShift, lessThan(9));
  });

  test('it goes into the intrinsic muscle on the body’s right, in its '
      'transverse fibres, under the superior longitudinal layer and clear '
      'of the inferior longitudinal', () {
    const Offset site = TongueAnatomy.site;
    expect(site.dx, lessThan(-3));
    expect(_in(TongueForm.homeMm, site), isTrue);
    expect(_in(TongueForm.superiorMm, site), isFalse);
    expect(_in(TongueForm.inferiorMm, Offset(-site.dx, site.dy)), isFalse);
    expect(site.dy, greaterThan(TongueForm.superiorFoot(site.dx) + 1));
    expect(_in(TongueForm.genioglossusMm, site), isFalse);
  });

  test('the intrinsic muscle lies under the mucous membrane and its '
      'aponeurosis, its fibres woven in it, the septum down its middle, the '
      'genioglossus rising into it from below', () {
    final List<Offset> home = TongueForm.homeMm;
    final Rect box = _bounds(home);
    expect(box.center.dx, closeTo(0, 1e-6));
    // Under the back by the mucosa and the aponeurosis, the median sulcus
    // a dip in it.
    final double back = TongueAnatomy.surface
        .map((Offset p) => p.dy)
        .reduce(math.min);
    expect(
      box.top,
      closeTo(back + TongueAnatomy.mucosaBack + TongueAnatomy.aponeurosis, 0.1),
    );
    expect(TongueForm.softMm.every((Offset p) => !_in(home, p)), isTrue);
    // Each transverse sheet runs from the septum out toward a margin, its
    // inner half inside the muscle.
    expect(TongueForm.transverseMm, hasLength(2 * TongueAnatomy.transverse));
    for (final List<Offset> sheet in TongueForm.transverseMm) {
      expect(sheet.first.dx.abs(), lessThan(0.5));
      expect(sheet.last.dx.abs(), greaterThan(20));
      for (final Offset p in sheet) {
        if (p.dx.abs() < 12) {
          expect(_in(home, p), isTrue, reason: '$p');
        }
      }
    }
    for (final List<Offset> fibre in TongueForm.verticalMm) {
      expect(_in(home, fibre[fibre.length ~/ 2]), isTrue);
    }
    // The genioglossus's fibres rise from its foot into the muscle.
    for (final List<Offset> fibre in TongueForm.genioFibresMm) {
      expect(fibre.first.dy, greaterThan(fibre.last.dy));
      expect(_in(TongueForm.genioglossusMm, fibre[fibre.length ~/ 4]), isTrue);
      expect(_in(home, fibre[fibre.length - 3]), isTrue);
    }
    // The septum on the midline, from under the back to the genioglossus's
    // foot.
    final List<Offset> septum = TongueForm.septumMm;
    expect(septum.every((Offset p) => p.dx == 0), isTrue);
    expect(septum.first.dy, lessThan(TongueForm.superiorFoot(0)));
    expect(septum.last.dy, TongueAnatomy.genioglossus.last.dy);
  });

  test('the mandible’s halves mirror one another, a first molar on each, '
      'its root in the bone and the canal low and lingual in its spongy '
      'bone', () {
    final List<List<Offset>> bones = TongueForm.bonesMm;
    expect(bones, hasLength(2));
    final Rect right = _bounds(bones[0]);
    final Rect left = _bounds(bones[1]);
    expect(right.left, closeTo(-left.right, 1e-9));
    expect(right.top, closeTo(left.top, 1e-9));
    // Its body 28 mm from crest to lower border.
    expect(left.bottom - TongueAnatomy.bone.first.dy, closeTo(28, 0.5));
    for (int side = 0; side < 2; side++) {
      final List<Offset> root = TongueForm.rootsMm[side];
      final int inBone = root.where((Offset p) => _in(bones[side], p)).length;
      expect(inBone / root.length, greaterThan(0.8));
      // The crown stands on it, above its crest.
      final Rect crown = _bounds(TongueForm.crownsMm[side]);
      expect(crown.bottom, lessThan(_bounds(bones[side]).top));
    }
    final (Offset canal, double r) = TongueAnatomy.canal;
    final List<Offset> spongy = TongueForm.spongyMm[1];
    expect(_in(spongy, canal), isTrue);
    final Rect bone = _bounds(TongueForm.bonesMm[1]);
    // Nearer the lingual cortex than the buccal, in the lower half.
    expect(canal.dx - bone.left, lessThan(bone.right - canal.dx));
    expect(
      canal.dy,
      greaterThan((TongueAnatomy.bone.first.dy + bone.bottom) / 2),
    );
    expect(r, lessThan(2));
  });

  test('the floor lies under the tongue: the sublingual glands on the '
      'mylohyoid, the geniohyoids over it, the vessels and the nerves '
      'among them, all inside the soft tissue', () {
    final List<Offset> soft = TongueForm.softMm;
    for (final List<Offset> gland in TongueForm.glandsMm) {
      expect(gland.every((Offset p) => _in(soft, p)), isTrue);
      expect(
        gland.where((Offset p) => _in(TongueForm.mylohyoidMm, p)),
        isEmpty,
      );
      expect(gland.where((Offset p) => _in(TongueForm.homeMm, p)), isEmpty);
    }
    for (final (Offset, double) disc in <(Offset, double)>[
      TongueAnatomy.artery,
      TongueAnatomy.vein,
      TongueAnatomy.duct,
      TongueAnatomy.lingualNerve,
      TongueAnatomy.hypoglossal,
      TongueAnatomy.comitans,
    ]) {
      final (Offset c, double r) = disc;
      for (final double side in <double>[-1, 1]) {
        final Offset at = Offset(side * c.dx, c.dy);
        expect(_in(soft, at), isTrue, reason: '$disc');
        expect(_in(TongueForm.homeMm, at), isFalse, reason: '$disc');
        expect(r, lessThan(1.5));
      }
    }
  });

  test('the papillae stand on the back, out of the soft tissue, none on its '
      'side', () {
    expect(TongueForm.papillaeMm.length, greaterThan(40));
    for (final List<Offset> papilla in TongueForm.papillaeMm) {
      final Offset tip = papilla[papilla.length ~/ 2];
      expect(_in(TongueForm.softMm, tip), isFalse, reason: '$tip');
      expect(tip.dx.abs(), lessThan(TongueAnatomy.filiformTo + 0.5));
      expect(tip.dy, lessThan(5));
    }
  });

  test('the step from the body meets the two outlines at the top’s '
      'middle, the margins and the foot, in the same order, and lands on '
      'the soft tissue’s own outline', () {
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final TongueForm form = _form(figure);
      final List<Offset> body = form.outlineAt(0);
      final List<Offset> own = form.outlineAt(1);
      final List<Offset> a = form.marksOf(body);
      final List<Offset> b = form.marksOf(own);
      expect(a, hasLength(4));
      expect(b, hasLength(4));
      for (final (List<Offset> marks, List<Offset> outline)
          in <(List<Offset>, List<Offset>)>[(a, body), (b, own)]) {
        final Rect box = _bounds(outline);
        expect(marks[0].dy - box.top, lessThan(0.25 * box.height));
        expect(marks[1].dx, greaterThan(box.center.dx));
        expect(box.bottom - marks[2].dy, lessThan(0.25 * box.height));
        expect(marks[3].dx, lessThan(box.center.dx));
      }
      expect(
        (_bounds(own).center - form.box.center).distance,
        lessThan(form.mm(0.5)),
        reason: figure.name,
      );
    }
  });

  test('its names point at what they name', () {
    final TongueForm form = _form(AnatomyFigure.female);
    expect(form.homeName, form.site);
    expect(
      _in(TongueForm.genioglossusMm, form.toMm(form.genioglossusName)),
      isTrue,
    );
    final Offset hyoglossus = form.toMm(form.hyoglossusName);
    expect(hyoglossus.dx, lessThan(0));
    expect(_in(form.hyoglossi.first, form.hyoglossusName), isTrue);
    expect(
      TongueForm.glandsMm.any(
        (List<Offset> g) => _in(g, form.toMm(form.glandName)),
      ),
      isTrue,
    );
    expect(_in(TongueForm.mylohyoidMm, form.toMm(form.mylohyoidName)), isTrue);
    // The mandible's name in its cortex, not its spongy bone.
    final Offset mandible = form.toMm(form.mandibleName);
    expect(_in(TongueForm.bonesMm[1], mandible), isTrue);
    expect(_in(TongueForm.spongyMm[1], mandible), isFalse);
  });

  test('it is the same tongue every time', () {
    final TongueForm a = _form(AnatomyFigure.female);
    final TongueForm b = _form(AnatomyFigure.female);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.home, b.home);
    expect(a.transverse, b.transverse);
    expect(a.trabeculae, b.trabeculae);
    expect(a.papillae, b.papillae);
    expect(a.lobules, b.lobules);
  });
}
