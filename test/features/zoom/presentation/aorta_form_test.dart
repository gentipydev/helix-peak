import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vessel/aorta_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vessel/aorta_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['blood vessel']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

AortaForm _form({AortaHome home = AortaHome.media}) =>
    AortaForm(length: _anatomy.metres / _view, view: _view, home: home);

void main() {
  test('the aorta is drawn at its real size: the card’s 12 cm long, 22 mm '
      'across or so, narrowing as it descends and leaning toward the middle '
      'line', () {
    final AortaForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    expect(form.box.height / form.scale, closeTo(124, 2));
    expect(2 * AortaForm.radiusAt(-40), inInclusiveRange(21.5, 23.5));
    expect(AortaForm.radiusAt(40), lessThan(AortaForm.radiusAt(-40)));
    // On the left of the column, nearer the middle line lower down.
    expect(AortaForm.centreAt(-40), greaterThan(AortaForm.centreAt(40)));
    expect(AortaForm.centreAt(0), greaterThan(0));
    expect(form.contains(form.site), isTrue);
  });

  test('its window is cut in steps on its front: the adventitia turned back, '
      'the media bared, and inside it the inner window through to the '
      'intima, the intercostal openings in it', () {
    for (final Offset p in AortaForm.innerMm) {
      expect(
        (Path()..addPolygon(AortaForm.outerMm, true)).contains(p),
        isTrue,
        reason: '$p',
      );
    }
    for (final Offset p in AortaForm.outerMm) {
      expect(
        (p.dx - AortaForm.centreAt(p.dy)).abs(),
        lessThan(AortaForm.radiusAt(p.dy)),
        reason: '$p',
      );
    }
    for (final Offset o in AortaForm.ostiaMm) {
      expect(AortaForm.inInner(o), isTrue);
    }
    expect(AortaForm.ostiaMm, hasLength(2));
  });

  test('the zoom goes into the media bared in the window, beside the inner '
      'window on the body’s right', () {
    final AortaForm form = _form();
    final Offset site = form.toMm(form.site);
    expect(AortaForm.inMedia(site), isTrue);
    expect(site.dx, lessThan(AortaForm.centreAt(site.dy)));
    expect(site.dy, closeTo(AortaAnatomy.windowAt, 1e-9));
  });

  test('round it the column fades out above and below, the intercostals '
      'leave it in pairs, the azygos climbs on the right with the duct '
      'between it and the aorta', () {
    final AortaForm form = _form();
    expect(AortaForm.columnShown(0), 1);
    expect(AortaForm.columnShown(AortaAnatomy.columnTo), 0);
    expect(form.bodies, hasLength(AortaAnatomy.bodies.length));
    expect(form.rightIntercostals, hasLength(AortaAnatomy.bodies.length));
    expect(form.leftIntercostals, hasLength(AortaAnatomy.bodies.length));
    for (final TubeCourse t in <TubeCourse>[
      ...form.rightIntercostals,
      ...form.leftIntercostals,
    ]) {
      // From under the aorta, fading out away from it.
      expect(form.contains(t.centres.first), isTrue);
      expect(t.shown.last, lessThan(0.05));
    }
    final double azygos = form
        .toMm(form.azygos.centres[form.azygos.length ~/ 2])
        .dx;
    final double duct = form.toMm(form.duct.centres[form.duct.length ~/ 2]).dx;
    expect(azygos, lessThan(duct));
    expect(duct, lessThan(AortaForm.centreAt(0) - AortaForm.radiusAt(0) + 1));
  });

  test('its home is told by the Atlas’s name for the cell, and its names '
      'point where they say', () {
    expect(AortaHome.of('Vascular endothelial cells'), AortaHome.intima);
    expect(AortaHome.of('Vascular smooth muscle cells'), AortaHome.media);
    expect(AortaHome.of('Pericytes'), AortaHome.adventitia);
    expect(AortaHome.of(null), AortaHome.media);
    final AortaForm media = _form();
    expect(media.homeName, media.site);
    expect(AortaForm.inInner(media.toMm(media.intimaName)), isTrue);
    expect(AortaForm.onAdventitia(media.toMm(media.adventitiaName)), isTrue);
    final AortaForm intima = _form(home: AortaHome.intima);
    expect(AortaForm.inInner(intima.toMm(intima.homeName)), isTrue);
    expect(AortaForm.inMedia(intima.toMm(intima.mediaName)), isTrue);
    final AortaForm adventitia = _form(home: AortaHome.adventitia);
    expect(
      AortaForm.onAdventitia(adventitia.toMm(adventitia.homeName)),
      isTrue,
    );
  });

  test('it is the same aorta every time', () {
    final AortaForm a = _form();
    final AortaForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.vasa, b.vasa);
    expect(a.lamellae, b.lamellae);
    expect(a.site, b.site);
  });
}
