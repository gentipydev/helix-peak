import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_layout.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_run_labels.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import '../../../support/test_catalog.dart';
import 'anatomy_fixture.dart';

GeneRecord _record(ProteinTarget target) => GeneRecordDto.fromJson(
  jsonDecode(File(target.mockAsset).readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

/// The gene page of [target] laid out exactly as [AnatomyCanvas] lays it out
/// in [viewport], and its runs named.
({AnatomyStage stage, AnatomyLayout layout, Size box, List<RunLabel> labels})
_plan(ProteinTarget target, Size viewport) {
  final AnatomyStage stage = AnatomyModel.derive(
    _record(target),
    chain: target.chain,
  ).stages.first;
  final Size box = Size(
    viewport.width,
    math.max(viewport.height, AnatomyLayout.heightFor(stage, viewport)),
  );
  final AnatomyLayout layout = AnatomyLayout.forStage(stage, box, viewport);
  return (
    stage: stage,
    layout: layout,
    box: box,
    labels: planRunLabels(stage, layout, measureLabel),
  );
}

/// One row of [run] as it is drawn: the cells it holds on that row, a row deep.
///
/// The row runs right to left when it is odd, so its two ends are taken
/// whichever way round they came.
Rect _rowRect(AnatomyLayout layout, StageRun run, int row) {
  final int lo = math.max(row * layout.columns, run.start);
  final int hi = math.min(
    row * layout.columns + layout.columns - 1,
    run.start + run.count - 1,
  );
  final Offset a = layout.centreOf(lo);
  final Offset b = layout.centreOf(hi);
  return Rect.fromLTRB(
    math.min(a.dx, b.dx) - layout.cell / 2,
    a.dy - layout.rowHeight / 2,
    math.max(a.dx, b.dx) + layout.cell / 2,
    a.dy + layout.rowHeight / 2,
  );
}

/// Holds every region of [target]'s gene page to having a name, and every name
/// to being written on the region it names.
///
/// Every region: a feature under [regionFloor] bases is punctuation — the stop
/// codon, a cut site, a stray residue trimmed off an end — and goes unnamed
/// unless it happens to hold its name whole. And a piece of a feature named on
/// another of its pieces has nothing left to say: the 5' UTR arrives either
/// side of intron 1, and nine cells of it are not where its name goes.
void _expectEveryRunNamed(ProteinTarget target, Size viewport) {
  final (:stage, :layout, :box, :labels) = _plan(target, viewport);
  final String where = '${target.slug} at $viewport';
  final String summary =
      '$where: ${labels.length} of ${stage.runs.length} runs named, '
      '${labels.where((RunLabel l) => l.size < runLabelMin).map((RunLabel l) => '"${l.text}" at ${l.size}').join(', ')} '
      'cut below the size their run earned';

  // At most one name per run, in run order, and none of them blank.
  int previous = -1;
  for (final RunLabel label in labels) {
    expect(label.run, greaterThan(previous), reason: summary);
    previous = label.run;
    expect(label.text.trim(), isNotEmpty, reason: summary);
    expect(
      stage.runs[label.run].writtenForms.toList(),
      contains(label.text),
      reason: '$summary — run ${label.run} set a name that is not its own',
    );
    expect(
      label.size,
      inInclusiveRange(runLabelFloor, runLabelMax),
      reason: '$summary — "${label.text}" was set at ${label.size}',
    );
  }

  // The whole of it, on its own run's cells. This is the promise the page used
  // to break: a name too wide for its run went into a pill beside it, and a
  // pill dodged other names but not other runs, so p53's third exon was named
  // over the fourth.
  for (final RunLabel label in labels) {
    final StageRun run = stage.runs[label.run];
    final String name = '$summary — "${label.text}" on ${run.label}';
    final int first = run.start ~/ layout.columns;
    final int last = (run.start + run.count - 1) ~/ layout.columns;
    final List<Rect> under = <Rect>[
      for (int row = first; row <= last; row++)
        if (_rowRect(layout, run, row).top < label.rect.bottom - 0.01 &&
            _rowRect(layout, run, row).bottom > label.rect.top + 0.01)
          _rowRect(layout, run, row),
    ];
    expect(under, isNotEmpty, reason: '$name sits on no row of its run');
    for (final Rect row in under) {
      expect(row.left, lessThanOrEqualTo(label.rect.left + 0.01), reason: name);
      expect(
        row.right,
        greaterThanOrEqualTo(label.rect.right - 0.01),
        reason: name,
      );
    }
    expect(
      under.first.top,
      lessThanOrEqualTo(label.rect.top + 0.01),
      reason: '$name overhangs the row above',
    );
    expect(
      under.last.bottom,
      greaterThanOrEqualTo(label.rect.bottom - 0.01),
      reason: '$name overhangs the row below',
    );
    // The rows it lies across are one band, not two with a fold between them.
    for (int i = 1; i < under.length; i++) {
      expect(
        under[i].top,
        closeTo(under[i - 1].bottom, 0.01),
        reason: '$name crosses a break in its run',
      );
    }
  }

  final Set<int> named = <int>{for (final RunLabel l in labels) l.run};
  final Set<int> features = <int>{
    for (final RunLabel l in labels) stage.runs[l.run].feature,
  };
  for (int i = 0; i < stage.runs.length; i++) {
    final StageRun run = stage.runs[i];
    if (run.isRegion && !named.contains(i)) {
      expect(
        features,
        contains(run.feature),
        reason: '$summary — ${run.label} went unnamed, and so did every other '
            'piece of it',
      );
    }
  }
}

void main() {
  setUpAll(loadAppFonts);

  // The canvas's real viewport on a phone, read off the screen rather than
  // re-derived here: it is what is left of the screen after its header, the
  // paginator and, on a scored protein, the toolbar.
  final Map<String, Size> phone = <String, Size>{};
  testWidgets('the phone viewport is read off the real screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final ProteinTarget target in TestCatalog.all) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: AnatomyScreen(
              target: target,
              record: _record(target),
              constraint: target.scored
                  ? ProteinConstraint.fromJson(
                      jsonDecode(
                            File(target.constraintAsset).readAsStringSync(),
                          )
                          as Map<String, dynamic>,
                      target,
                    )
                  : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      phone[target.slug] = tester
          .widget<AnatomyCanvas>(find.byType(AnatomyCanvas))
          .viewport;
      await tester.pumpWidget(const SizedBox());
    }
    expect(phone.length, TestCatalog.all.length);
  });

  group('every run of every gene page is named on itself', () {
    for (final ProteinTarget target in TestCatalog.all) {
      test('${target.slug} on a phone', () {
        _expectEveryRunNamed(target, phone[target.slug]!);
      });
      test('${target.slug} on a small phone', () {
        _expectEveryRunNamed(target, const Size(360, 480));
      });
      test('${target.slug} on a tablet', () {
        _expectEveryRunNamed(target, const Size(820, 960));
      });
    }
  });

  test('punctuation is never abbreviated to get itself named', () {
    // The three-base stop codon, the cut sites, the stray residues trimmed off
    // a precursor's ends: they are read off the colours either side of them,
    // and shortening one to fit would put more type on the page than the thing
    // it names. Where the cells are fat enough to hold the whole name — a cut
    // site on a tablet — it is written, as it always was.
    for (final ProteinTarget target in TestCatalog.all) {
      final (:stage, :layout, :box, :labels) = _plan(
        target,
        const Size(390, 676),
      );
      for (final RunLabel label in labels) {
        final StageRun run = stage.runs[label.run];
        if (run.isRegion) {
          continue;
        }
        expect(
          run.labelForms.toList(),
          contains(label.text),
          reason: '${target.slug} abbreviated "${run.label}" to '
              '"${label.text}" to fit ${run.lengthBp} bases',
        );
      }
    }
  });

  test('a name is abbreviated only as far as its run makes it', () {
    // p53's third exon is twenty-two bases straddling a row end, with about
    // eighteen points of row against a thirty-eight point name: it is the run
    // the page used to name in a pill over its neighbour, and the one that has
    // to reach the shortest rung. Nothing wider than it does.
    final ProteinTarget p53 = TestCatalog.all.firstWhere(
      (ProteinTarget t) => t.slug == 'p53',
    );
    final (:stage, :layout, :box, :labels) = _plan(p53, const Size(360, 676));
    final Map<String, String> written = <String, String>{
      for (final RunLabel l in labels) stage.runs[l.run].label: l.text,
    };
    expect(written['exon 3'], 'E3');
    expect(written['exon 4'], 'exon 4');
    expect(written['intron 10'], 'intron 10');
  });
}
