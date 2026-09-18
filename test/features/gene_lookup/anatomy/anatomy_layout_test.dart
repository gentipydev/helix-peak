import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_layout.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_ruler.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_selection.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import 'anatomy_fixture.dart';

/// A 390pt phone, less the screen gutters, less header and caption.
const Size _canvas = Size(342, 410);

AnatomyLayout _layoutFor(AnatomyStage stage) =>
    AnatomyLayout.forStage(stage, _canvas, _canvas);

void main() {
  final AnatomyModel model = AnatomyModel.derive(insulin());

  group('serpentine order', () {
    test('consecutive cells are always physically adjacent', () {
      for (final AnatomyStage stage in model.stages) {
        final AnatomyLayout layout = _layoutFor(stage);
        // Only the gene reads like a polymer. Every lettered page reads like
        // text — see the raster groups below — so the step from the end of one
        // row to the start of the next is a carriage return, not one cell.
        if (!layout.serpentine) {
          expect(stage.kind, isNot(StageKind.gene));
          continue;
        }
        for (final StageBlock block in stage.blocks) {
          for (int i = block.start; i < block.start + block.count - 1; i++) {
            final Offset a = layout.centreOf(i);
            final Offset b = layout.centreOf(i + 1);
            final double distance = (a - b).distance;
            // One pitch, in whichever direction the step was. They are the same
            // number everywhere but the gene, where a cell is taller than it is
            // wide so that the rows can carry a name.
            final double pitch = a.dy == b.dy ? layout.cell : layout.rowHeight;
            expect(
              distance,
              closeTo(pitch, 1e-6),
              reason:
                  'cells $i and ${i + 1} of ${stage.label} are $distance '
                  'apart, not one cell',
            );
          }
        }
      }
    });

    test('a row end sits directly above the next row start', () {
      final AnatomyLayout layout = _layoutFor(model.stages.first);
      final int last = layout.columns - 1;
      expect(layout.centreOf(last).dx, layout.centreOf(last + 1).dx);
      expect(
        layout.centreOf(last + 1).dy - layout.centreOf(last).dy,
        closeTo(layout.rowHeight, 1e-6),
      );

      // ...and the row after that turns back at the other edge.
      final int second = 2 * layout.columns - 1;
      expect(layout.centreOf(second).dx, layout.centreOf(second + 1).dx);
      expect(layout.centreOf(second).dx, lessThan(layout.centreOf(last).dx));
    });

    test('rows alternate direction rather than restarting', () {
      final AnatomyLayout layout = _layoutFor(model.stages.first);
      expect(layout.centreOf(1).dx, greaterThan(layout.centreOf(0).dx));
      expect(
        layout.centreOf(layout.columns + 1).dx,
        lessThan(layout.centreOf(layout.columns).dx),
      );
    });
  });

  /// The transcript page is the one stage that reads like text. A codon laid
  /// right to left would display `ATG` as `GTA`, and the whole argument of that
  /// page is that the frame is legible.
  group('raster order, on the transcript page', () {
    final AnatomyStage mrna = model.stages[1];
    final AnatomyLayout layout = _layoutFor(mrna);

    test('is not serpentine, and draws no row-end turns', () {
      expect(layout.serpentine, isFalse);
      expect(layout.connectors().computeMetrics().isEmpty, isTrue);
    });

    test('every row starts at the left margin', () {
      final double left = layout.origin.dx + layout.cell / 2;
      for (final StageBlock block in mrna.blocks) {
        final int rows = (block.count / layout.columns).ceil();
        for (int r = 0; r < rows; r++) {
          expect(
            layout.centreOf(block.start + r * layout.columns).dx,
            closeTo(left, 1e-6),
            reason: 'row $r of ${block.label}',
          );
        }
      }
    });

    test('a partial last row stops short on the right', () {
      final StageBlock utr5 = mrna.blocks.first;
      final int last = utr5.start + utr5.count - 1;
      expect(utr5.count % layout.columns, isNot(0));
      expect(
        layout.centreOf(last).dx,
        lessThan(layout.centreOf(layout.columns - 1).dx),
      );
    });

    test('bases are 20pt on a 21pt pitch, with a 5pt corner', () {
      expect(layout.cell, AnatomyLayout.basePitch);
      expect(layout.side, AnatomyLayout.baseSide);
      expect(layout.rowSide, AnatomyLayout.baseSide);
      expect(layout.radius, AnatomyLayout.baseRadius);
    });

    test('columns come in whole codons, so none straddles a row', () {
      expect(layout.columns % 3, 0);
      expect(layout.columns, greaterThanOrEqualTo(3));
    });

    test('the groove falls between codons and nowhere else', () {
      final int start = mrna.blocks[1].start;
      final double within = layout.centreOf(start + 1).dx -
          layout.centreOf(start).dx;
      final double across = layout.centreOf(start + 3).dx -
          layout.centreOf(start + 2).dx;
      expect(within, closeTo(layout.cell, 1e-6));
      expect(across, closeTo(layout.cell + layout.codonGap, 1e-6));
      expect(layout.codonGap, greaterThan(0));
    });

    test('the codon rows are spaced apart, and only they are', () {
      double drop(int block, int row) =>
          layout.centreOf(mrna.blocks[block].start + (row + 1) * layout.columns).dy -
          layout.centreOf(mrna.blocks[block].start + row * layout.columns).dy;

      // A codon is three squares with air either side of it. Without this it
      // was also three squares stacked flush against the three above, which
      // read as a column of them rather than as a row of threes.
      expect(drop(1, 0), closeTo(layout.rowHeight + AnatomyLayout.codonRise, 1e-6));
      expect(drop(1, 5), closeTo(drop(1, 0), 1e-6));

      // The untranslated ends are not read in threes and are not spaced as
      // though they were.
      expect(drop(0, 0), closeTo(layout.rowHeight, 1e-6));
      expect(drop(2, 0), closeTo(layout.rowHeight, 1e-6));

      // The air goes between the rows, not into the squares: a base is the
      // same 20pt tile it is in every other block.
      expect(layout.rowSide, AnatomyLayout.baseSide);
      expect(
        layout.rectOf(mrna.blocks[1].start).height,
        layout.rectOf(mrna.blocks[0].start).height,
      );
    });

    test('the spacing is reserved, not borrowed from the page', () {
      // The rows the transcript reserves have to account for it, or the 3' UTR
      // is laid over the foot of the coding sequence and the scroll stops
      // short of its own last row.
      final StageBlock cds = mrna.blocks[1];
      final int rows = (cds.count / layout.columns).ceil();
      final double foot =
          layout.centreOf(cds.start + cds.count - 1).dy +
          layout.rowPitchOf(1) / 2;

      expect(
        foot - layout.centreOf(cds.start).dy + layout.rowPitchOf(1) / 2,
        closeTo(rows * layout.rowPitchOf(1), 1e-6),
      );
      expect(layout.labelBandOf(2)!.top, greaterThan(foot));
      expect(layout.size.height, greaterThan(foot));
    });

    test('the untranslated ends keep a uniform pitch', () {
      for (final int block in <int>[0, 2]) {
        final int start = mrna.blocks[block].start;
        for (int k = 0; k < 4; k++) {
          expect(
            layout.centreOf(start + k + 1).dx - layout.centreOf(start + k).dx,
            closeTo(layout.cell, 1e-6),
            reason: 'cell $k of ${mrna.blocks[block].label}',
          );
        }
      }
    });

    test('it is taller than the screen, and never wider', () {
      expect(layout.size.width, lessThanOrEqualTo(_canvas.width + 1e-9));
      expect(layout.size.height, greaterThan(_canvas.height));
      expect(
        AnatomyLayout.heightFor(mrna, _canvas),
        closeTo(layout.size.height, 1e-9),
      );
    });

    test('each region gets a name band, above its own first row', () {
      for (int b = 0; b < mrna.blocks.length; b++) {
        final Rect? band = layout.labelBandOf(b);
        expect(band, isNotNull, reason: 'block $b');
        expect(band!.height, AnatomyLayout.labelPill);
        expect(band.width, closeTo(layout.bandWidth, 1e-9));
        expect(
          band.bottom,
          lessThan(layout.rectOf(mrna.blocks[b].start).top),
          reason: 'the band for block $b overlaps its own first row',
        );
      }
    });

    test('a name band is the only thing between one region and the next', () {
      // The band carries its own air; the block gap must not be charged again
      // on top of it, or a named region sits three rows of bases clear of the
      // one above.
      for (int b = 1; b < mrna.blocks.length; b++) {
        final StageBlock above = mrna.blocks[b - 1];
        // The foot of the last row of pitch, which is half a mortar below the
        // drawn cell — and half of the codon rise as well, on the block that
        // spaces its rows out.
        final double foot =
            layout.centreOf(above.start + above.count - 1).dy +
            layout.rowPitchOf(b - 1) / 2;
        expect(
          layout.labelBandOf(b)!.top - foot,
          closeTo(AnatomyLayout.labelGap, 1e-9),
          reason: 'block $b is held off block ${b - 1} by more than its band',
        );
      }
    });

    test('a tap lands on the cell it was aimed at, grooves and all', () {
      for (final int cell in <int>[0, 14, 58, 59, 61, 62, 200, 391, 464]) {
        expect(
          layout.hitTest(layout.centreOf(cell)),
          cell,
          reason: 'cell $cell',
        );
      }
    });
  });

  group('the reading frame opening', () {
    final AnatomyStage mrna = model.stages[1];
    final AnatomyLayout open = _layoutFor(mrna);
    final AnatomyLayout shut = open.opened(0);

    final int cds = mrna.blocks[1].start;

    test('it arrives flush: a closed frame is a uniform pitch', () {
      for (int k = 0; k < 8; k++) {
        expect(
          shut.centreOf(cds + k + 1).dx - shut.centreOf(cds + k).dx,
          closeTo(shut.cell, 1e-6),
          reason: 'cell $k of the coding sequence',
        );
      }
    });

    test('it opens onto exactly the layout it would have had', () {
      for (final int cell in <int>[0, 59, 62, 200, 391, 464]) {
        expect(
          open.opened(1).centreOf(cell),
          open.centreOf(cell),
          reason: 'cell $cell',
        );
      }
    });

    test('the frame is the only thing that moves', () {
      // The untranslated ends share the coding sequence's origin and column
      // count and have no frame of their own, so the grooves must leave every
      // one of their cells exactly where it was.
      for (final int block in <int>[0, 2]) {
        final StageBlock region = mrna.blocks[block];
        for (int k = 0; k < region.count; k++) {
          expect(
            shut.centreOf(region.start + k),
            open.centreOf(region.start + k),
            reason: 'cell $k of ${region.label}',
          );
        }
      }
    });

    test("it sweeps 5' to 3' rather than clicking apart all at once", () {
      const double half = 0.5;
      final AnatomyLayout mid = open.opened(half);
      final int rows = (mrna.blocks[1].count / open.columns).ceil();
      final int last = cds + (rows - 1) * open.columns;

      // Every row opens on the same curve, each a little behind the one above.
      expect(mid.openAt(cds), greaterThan(mid.openAt(last)));
      expect(mid.openAt(cds), greaterThan(0));

      // And the sweep is a sweep, not a shuffle: the first row is genuinely
      // ahead, and the last has barely set off.
      expect(mid.openAt(cds), greaterThan(0.8));
      expect(mid.openAt(last), lessThan(0.2));
    });

    test('both ends of the sweep are exact', () {
      final int rows = (mrna.blocks[1].count / open.columns).ceil();
      final int last = cds + (rows - 1) * open.columns;
      for (final int cell in <int>[cds, last]) {
        expect(open.opened(0).openAt(cell), 0);
        expect(open.opened(1).openAt(cell), 1);
      }
    });

    test('a tap lands on the square under the finger mid-sweep', () {
      // The whole reason the groove lives in the layout: [hitTest] and
      // [centreOf] walk the same arithmetic, so a frame caught halfway open is
      // still honest about what is under a given point.
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final AnatomyLayout frame = open.opened(t);
        for (final int cell in <int>[0, 58, 59, 61, 62, 200, 391, 464]) {
          expect(
            frame.hitTest(frame.centreOf(cell)),
            cell,
            reason: 'cell $cell at $t',
          );
        }
      }
    });

    test('the page it scrolls does not resize while the frame opens', () {
      // The screen sizes its scroll box off this. A width or a height that
      // moved with the grooves would reflow the page under the reader.
      for (final double t in <double>[0, 0.5, 1]) {
        expect(open.opened(t).size, open.size, reason: 'at $t');
      }
    });
  });

  group('the gene, at a glance', () {
    final AnatomyStage gene = model.stages.first;
    final AnatomyLayout layout = _layoutFor(gene);

    test('introns take about two thirds of the squares', () {
      int introns = 0;
      for (int i = 0; i < gene.count; i++) {
        if (model.transcriptRoleAt(gene.positionAt(i))?.kind ==
            RoleKind.intron) {
          introns++;
        }
      }
      expect(introns / gene.count, closeTo(0.675, 0.01));
    });

    test('intron 2 reads as one run, not as disconnected stripes', () {
      final List<int> cells = <int>[
        for (int i = 0; i < gene.count; i++)
          if (model.transcriptRoleAt(gene.positionAt(i))?.index == 1 &&
              model.transcriptRoleAt(gene.positionAt(i))?.kind ==
                  RoleKind.intron)
            i,
      ];
      expect(cells.length, 787);
      expect(cells.last - cells.first, cells.length - 1);

      // It wraps many rows and every step of it is still one cell long.
      final Set<double> rows = cells
          .map((int i) => layout.centreOf(i).dy)
          .toSet();
      expect(rows.length, greaterThan(15));
      for (int k = 0; k < cells.length - 1; k++) {
        final Offset a = layout.centreOf(cells[k]);
        final Offset b = layout.centreOf(cells[k + 1]);
        expect(
          (a - b).distance,
          closeTo(a.dy == b.dy ? layout.cell : layout.rowHeight, 1e-6),
        );
      }
    });

    test('the exons keep their 42 : 204 : 219 proportions', () {
      final Map<int, int> perExon = <int, int>{};
      for (int i = 0; i < gene.count; i++) {
        final Role? role = model.transcriptRoleAt(gene.positionAt(i));
        if (role?.kind == RoleKind.exon) {
          perExon[role!.index] = (perExon[role.index] ?? 0) + 1;
        }
      }
      expect(perExon[0], 42);
      expect(perExon[1], 204);
      expect(perExon[2], 219);

      final Role? intron1 = model.transcriptRoleAt(5028);
      final Role? intron2 = model.transcriptRoleAt(6000);
      expect(intron2!.lengthBp / intron1!.lengthBp, closeTo(4.4, 0.05));
    });
  });

  group('the zoom arc', () {
    test('squares grow as the count falls', () {
      final List<double> sizes = model.stages
          .map((AnatomyStage s) => _layoutFor(s).cell)
          .toList();

      for (int i = 0; i < sizes.length - 1; i++) {
        expect(
          sizes[i + 1],
          greaterThan(sizes[i]),
          reason: 'stage ${i + 2} should be larger than stage ${i + 1}',
        );
      }

      // The mature stage used to be the exception — three separate blocks cost
      // vertical room one continuous block does not, and it came out smaller
      // than the page before it. It no longer is, even now that all four of its
      // and the precursor's blocks carry a name band: merging the precursor
      // pages gave the arc one fewer step to climb, which was worth more than
      // the bands cost.
    });

    test('every fitted stage fits the canvas it was given', () {
      for (final AnatomyStage stage in model.stages) {
        final AnatomyLayout layout = _layoutFor(stage);
        // The transcript page is the one that does not fit and is not meant
        // to — it is checked in the raster group instead.
        if (stage.kind == StageKind.mrna) {
          continue;
        }
        expect(layout.size.width, lessThanOrEqualTo(_canvas.width + 1e-9));
        expect(layout.size.height, lessThanOrEqualTo(_canvas.height + 1e-9));
        expect(layout.origin.dx, greaterThanOrEqualTo(-1e-9));
        expect(layout.origin.dy, greaterThanOrEqualTo(-1e-9));
      }
    });

    test('no stage spends more than an eighth of its pitch on mortar', () {
      // Pinned to [_canvas] on purpose: between a 6 and an 8.3 point cell the
      // _minGap floor legitimately exceeds an eighth, so this is a claim about
      // a phone, not about every canvas.
      // The gene is not among them: it is drawn edge to edge, so it has no
      // mortar to spend anything on, and its gap is a number no pixel answers
      // to.
      for (final AnatomyStage stage in model.stages.skip(1)) {
        final AnatomyLayout layout = _layoutFor(stage);
        expect(
          layout.gap / layout.cell,
          lessThan(0.12),
          reason:
              '${stage.label} at a ${layout.cell.toStringAsFixed(2)} pt cell',
        );
      }
    });

    test('the gene is solid, every page after it is lettered', () {
      expect(_layoutFor(model.stages[0]).isLettered, isFalse);
      for (final AnatomyStage stage in model.stages.skip(1)) {
        expect(_layoutFor(stage).isLettered, isTrue, reason: stage.label);
      }
    });

    test('a lettered cell is the tile the transcript page fixes', () {
      // A residue was a hard-cornered square with twice the mortar, which put
      // two different objects on two adjacent pages of one grid. The gene is
      // the exception it is everywhere else: its cells are drawn edge to edge
      // so a run fuses into one shape, and a corner is what would stop that.
      final AnatomyLayout gene = _layoutFor(model.stages[0]);
      expect(gene.radius, 0);

      for (final AnatomyStage stage in model.stages.skip(1)) {
        final AnatomyLayout layout = _layoutFor(stage);
        expect(
          layout.radius / layout.side,
          closeTo(AnatomyLayout.baseRadius / AnatomyLayout.baseSide, 1e-9),
          reason: '${stage.label} corner',
        );
        expect(
          layout.gap / layout.cell,
          closeTo(AnatomyLayout.baseGap / AnatomyLayout.basePitch, 1e-9),
          reason: '${stage.label} mortar',
        );
      }
    });
  });

  group('blocks', () {
    test('a fitted stage reserves the bands its blocks are named in', () {
      // The bands never used to be drawn anywhere but the transcript page,
      // because `fit` never set `labelRows` — so the three chains carried names
      // in the model that nothing rendered. A band is charged in points off the
      // canvas before the sweep and only then converted back into rows, because
      // here the row height is the thing being solved for.
      for (final AnatomyStage stage in <AnatomyStage>[
        model.stages[2],
        model.stages.last,
      ]) {
        final AnatomyLayout layout = _layoutFor(stage);
        expect(layout.labelRows, greaterThan(0), reason: stage.label);
        for (int b = 0; b < stage.blocks.length; b++) {
          final Rect? band = layout.labelBandOf(b);
          expect(band, isNotNull, reason: '${stage.label} block $b');
          expect(band!.height, AnatomyLayout.labelPill);
          expect(
            band.bottom,
            lessThan(layout.rectOf(stage.blocks[b].start).top),
            reason: '${stage.label} band $b overlaps its own first row',
          );
        }
        expect(
          layout.size.height,
          lessThanOrEqualTo(_canvas.height + 1e-9),
          reason: '${stage.label} outgrew its canvas once banded',
        );
      }
    });

    test('the gene reserves no band, having nothing to name', () {
      expect(_layoutFor(model.stages[0]).labelRows, 0);
      expect(_layoutFor(model.stages[0]).labelBandOf(0), isNull);
    });

    test('the mature stage lays each chain out on its own', () {
      final AnatomyStage mature = model.stages.last;
      final AnatomyLayout layout = _layoutFor(mature);
      expect(mature.blocks.length, 3);

      final List<double> tops = <double>[
        for (final StageBlock block in mature.blocks)
          layout.centreOf(block.start).dy,
      ];
      expect(tops[1], greaterThan(tops[0]));
      expect(tops[2], greaterThan(tops[1]));

      // Each chain starts a fresh row rather than continuing the one before.
      for (final StageBlock block in mature.blocks) {
        expect(layout.centreOf(block.start).dx, closeTo(
          layout.origin.dx + layout.cell / 2,
          1e-6,
        ));
      }
    });
  });

  group('rows tall enough to write on', () {
    // The gene page as the phone actually gives it: full width, because it
    // takes no horizontal inset, and what is left under the header and above
    // the caption.
    const Size phone = Size(390, 498);

    test('a gene that fits trades width for height, and stays on one screen', () {
      final AnatomyLayout layout = AnatomyLayout.forStage(
        model.stages.first,
        phone,
        phone,
      );

      expect(layout.rowHeight, greaterThanOrEqualTo(AnatomyLayout.geneRow));
      expect(
        layout.cell,
        lessThan(layout.rowHeight),
        reason: 'the height is bought out of the width, not out of the screen',
      );
      expect(layout.size.height, lessThanOrEqualTo(phone.height + 1e-9));
      expect(layout.size.width, lessThanOrEqualTo(phone.width + 1e-9));
    });

    test('a name fits the row it is written on', () {
      // Both cut sites are one row of six cells, and both carry their name.
      // The painter caps a name at four fifths of the row it sits in, so this
      // is the number that decides whether `RR site` is drawn at all.
      final AnatomyLayout layout = AnatomyLayout.forStage(
        model.stages.first,
        phone,
        phone,
      );
      expect(layout.rowHeight * 0.8, greaterThanOrEqualTo(11));

      // ...and six cells across still has the room to hold it.
      expect(6 * layout.cell, greaterThan(50));
    });

    test('every stage but the gene keeps its squares', () {
      for (final AnatomyStage stage in model.stages.skip(1)) {
        final AnatomyLayout layout = AnatomyLayout.forStage(stage, phone, phone);
        expect(
          layout.rowHeight,
          layout.cell,
          reason: '${stage.label} is drawn as cells you can count',
        );
      }
    });

    test('a sequence too long for the trade keeps its rows and scrolls', () {
      // Past the point where the width has run out of columns, the rows keep
      // the height a name needs and the grid runs past the bottom of the
      // screen instead, pinned to the top so the scroll starts at its first row.
      const List<StageBlock> blocks = <StageBlock>[
        StageBlock(start: 0, count: 100000),
      ];
      final AnatomyLayout layout = AnatomyLayout.fit(
        blocks: blocks,
        canvas: phone,
        minRow: AnatomyLayout.geneRow,
      );
      expect(layout.rowHeight, AnatomyLayout.geneRow);
      expect(layout.cell, lessThan(layout.rowHeight));
      expect(layout.size.height, greaterThan(phone.height));
      expect(layout.size.width, lessThanOrEqualTo(phone.width + 1e-9));
      expect(layout.origin.dy, 0);

      // Every cell is still where a tap finds it, all the way down.
      for (int i = 0; i < 100000; i += 997) {
        expect(layout.hitTest(layout.centreOf(i)), i, reason: 'cell $i');
      }
    });

    test('a scrolled layout is raised by exactly its offset', () {
      final AnatomyLayout layout = AnatomyLayout.forStage(
        model.stages.first,
        phone,
        phone,
      );
      final AnatomyLayout raised = layout.raisedBy(120);
      expect(identical(layout.raisedBy(0), layout), isTrue);
      for (final int i in <int>[0, 700, model.stages.first.count - 1]) {
        expect(raised.centreOf(i), layout.centreOf(i) - const Offset(0, 120));
      }
    });
  });

  group('tiles large enough to letter', () {
    // The residue pages as a phone gives them.
    const Size phone = Size(390, 560);

    void expectScrollingTiles(AnatomyLayout layout, int count) {
      expect(layout.cell, greaterThanOrEqualTo(AnatomyLayout.residuePitch));
      expect(layout.rowHeight, layout.cell, reason: 'still a square');
      expect(layout.isLettered, isTrue);
      expect(layout.size.height, greaterThan(phone.height));
      expect(layout.size.width, lessThanOrEqualTo(phone.width + 1e-9));
      expect(layout.origin.dy, 0, reason: 'the scroll starts at the first row');
      for (int i = 0; i < count; i += 97) {
        expect(layout.hitTest(layout.centreOf(i)), i, reason: 'cell $i');
      }
      expect(layout.hitTest(layout.centreOf(count - 1)), count - 1);
    }

    test('a protein too long for one screen keeps its tiles and scrolls', () {
      // Dystrophin's length. Fitted to the phone it came out at eight points,
      // too small for a letter or a finger.
      const int count = 3685;
      final AnatomyLayout layout = AnatomyLayout.fit(
        blocks: const <StageBlock>[StageBlock(start: 0, count: count)],
        canvas: phone,
        minCell: AnatomyLayout.residuePitch,
        tile: true,
      );
      expectScrollingTiles(layout, count);
    });

    test('named chains keep their bands above their first rows', () {
      final AnatomyLayout layout = AnatomyLayout.fit(
        blocks: const <StageBlock>[
          StageBlock(start: 0, count: 1800, label: 'first chain'),
          StageBlock(start: 1800, count: 1800, label: 'second chain'),
        ],
        canvas: phone,
        minCell: AnatomyLayout.residuePitch,
        tile: true,
      );
      expectScrollingTiles(layout, 3600);
      for (final int b in <int>[0, 1]) {
        final Rect band = layout.labelBandOf(b)!;
        expect(band.bottom, lessThan(layout.rectOf(layout.blocks[b].start).top));
      }
    });

    test('a protein that fits is fitted as it always was', () {
      for (final AnatomyStage stage in model.stages.skip(2)) {
        expect(
          AnatomyLayout.fit(
            blocks: stage.blocks,
            canvas: phone,
            minCell: AnatomyLayout.residuePitch,
            tile: true,
          ).cell,
          AnatomyLayout.fit(blocks: stage.blocks, canvas: phone, tile: true).cell,
          reason: stage.label,
        );
        expect(AnatomyLayout.heightFor(stage, phone), 0, reason: stage.label);
      }
    });
  });

  group('folding a long region', () {
    // Dystrophin's transcript, as blocks: a short 5' UTR, an 11,058-base coding
    // sequence and a 2,691-base 3' UTR.
    const List<StageBlock> blocks = <StageBlock>[
      StageBlock(start: 0, count: 244, label: "5' UTR"),
      StageBlock(start: 244, count: 11058, label: 'Coding sequence', framed: true),
      StageBlock(start: 11302, count: 2691, label: "3' UTR"),
    ];
    const double width = 402;
    final AnatomyLayout layout = AnatomyLayout.intrinsic(
      blocks: blocks,
      width: width,
    );

    test('only the regions over the threshold fold', () {
      expect(layout.foldBandOf(0), isNull);
      expect(layout.foldBandOf(1), isNotNull);
      expect(layout.foldBandOf(2), isNotNull);
      expect(layout.hiddenCount(0), 0);
      for (final int b in <int>[1, 2]) {
        expect(layout.hiddenCount(b) % layout.columns, 0, reason: 'whole rows');
        expect(
          layout.hiddenCount(b),
          greaterThan(blocks[b].count - AnatomyLayout.foldAbove),
        );
      }
    });

    test('the start and the stop codon are both drawn, either side of the fold', () {
      final StageBlock cds = blocks[1];
      final Rect fold = layout.foldBandOf(1)!;
      for (int k = 0; k < 3; k++) {
        expect(layout.isHidden(cds.start + k), isFalse);
        expect(layout.centreOf(cds.start + k).dy, lessThan(fold.top));
        final int stop = cds.start + cds.count - 3 + k;
        expect(layout.isHidden(stop), isFalse);
        expect(layout.centreOf(stop).dy, greaterThan(fold.bottom));
      }
      // The head keeps whole codon rows, so no codon is cut by the fold.
      expect(layout.foldFrom[1] * layout.columns % 3, 0);
    });

    test('a hidden cell sits at its fold', () {
      final StageBlock cds = blocks[1];
      final int middle = cds.start + cds.count ~/ 2;
      expect(layout.isHidden(middle), isTrue);
      expect(layout.centreOf(middle), layout.foldBandOf(1)!.center);
    });

    test('every drawn cell is found where it is drawn, and the fold is not a cell', () {
      int shown = 0;
      for (int i = 0; i < 13993; i++) {
        if (layout.isHidden(i)) {
          continue;
        }
        shown++;
        expect(layout.hitTest(layout.centreOf(i)), i, reason: 'cell $i');
      }
      expect(shown, 13993 - layout.hiddenCount(1) - layout.hiddenCount(2));
      expect(layout.hitTest(layout.foldBandOf(1)!.center), -1);
      expect(layout.hitTest(layout.foldBandOf(2)!.center), -1);
    });

    test('names stay above their first rows, and nothing overlaps the folds', () {
      for (int b = 0; b < blocks.length; b++) {
        expect(
          layout.labelBandOf(b)!.bottom,
          lessThan(layout.rectOf(blocks[b].start).top),
        );
      }
      final Rect fold = layout.foldBandOf(1)!;
      final int lastHead = blocks[1].start + layout.foldFrom[1] * layout.columns - 1;
      final int firstTail = blocks[1].start + layout.foldTo[1] * layout.columns;
      expect(layout.rectOf(lastHead).bottom, lessThanOrEqualTo(fold.top));
      expect(layout.rectOf(firstTail).top, greaterThanOrEqualTo(fold.bottom));
    });

    test('the page is a few screens rather than twenty-five', () {
      final AnatomyLayout whole = AnatomyLayout.intrinsic(
        blocks: const <StageBlock>[
          StageBlock(start: 0, count: 244, label: "5' UTR"),
          StageBlock(start: 244, count: 999, label: 'Coding sequence', framed: true),
        ],
        width: width,
      );
      expect(whole.foldTo, isEmpty, reason: 'nothing under the threshold folds');
      expect(layout.size.height, lessThan(4 * 700));
    });

    test('a short transcript is laid out exactly as before', () {
      final AnatomyStage mrna = model.stages[1];
      final AnatomyLayout insulin = AnatomyLayout.intrinsic(
        blocks: mrna.blocks,
        width: 342,
      );
      expect(insulin.foldTo, isEmpty);
      for (int i = 0; i < mrna.count; i++) {
        expect(insulin.isHidden(i), isFalse);
      }
    });
  });

  group('hit testing', () {
    test('round-trips every cell of every stage', () {
      for (final AnatomyStage stage in model.stages) {
        final AnatomyLayout layout = _layoutFor(stage);
        for (int i = 0; i < stage.count; i++) {
          expect(
            layout.hitTest(layout.centreOf(i)),
            i,
            reason: 'cell $i of ${stage.label}',
          );
        }
      }
    });

    test('misses outside the grid', () {
      final AnatomyLayout layout = _layoutFor(model.stages.first);
      expect(layout.hitTest(const Offset(-10, 10)), -1);
      expect(layout.hitTest(Offset(_canvas.width + 10, 10)), -1);
      expect(layout.hitTest(Offset(10, layout.origin.dy - layout.cell)), -1);
    });

    test('misses the empty tail of a partly filled last row', () {
      final AnatomyStage mature = model.stages.last;
      final AnatomyLayout layout = _layoutFor(mature);

      final StageBlock partial = mature.blocks.firstWhere(
        (StageBlock b) => b.count % layout.columns != 0,
      );
      final int last = partial.start + partial.count - 1;
      final int row = (partial.count - 1) ~/ layout.columns;

      // The empty tail lies in whichever direction that row was still running.
      final double onward = layout.serpentine && row.isOdd ? -1 : 1;
      expect(layout.hitTest(layout.centreOf(last)), last);
      expect(
        layout.hitTest(layout.centreOf(last).translate(onward * layout.cell, 0)),
        -1,
      );
    });
  });

  group('a region opened into its DNA', () {
    // Intron 2, the 787 bases a tap at 6,000 opens.
    final AnatomyStage dna = AnatomySelection.of(model, 6000).stage;
    const List<double> widths = <double>[320, 375, 390, 402, 440];

    AnatomyLayout layoutAt(double width) =>
        AnatomyLayout.forStage(dna, Size(width, 700), Size(width, 700));

    test('its bases are the transcript tile, large enough to tap', () {
      for (final double width in widths) {
        final AnatomyLayout layout = layoutAt(width);
        expect(
          layout.side,
          greaterThanOrEqualTo(AnatomyLayout.inspectionSide),
          reason: '$width',
        );
        expect(layout.side, greaterThan(AnatomyLayout.baseSide));
        expect(layout.rowSide, layout.side);
        expect(
          layout.radius / layout.side,
          closeTo(AnatomyLayout.tileRadiusRatio, 1e-9),
        );
        expect(
          layout.gap / layout.cell,
          closeTo(AnatomyLayout.tileGapRatio, 1e-9),
        );
      }
    });

    test('its rows fit as many tiles as they can between the gutters', () {
      final double ruler = AnatomyRuler.gutterFor(dna);
      expect(ruler, greaterThan(0));
      for (final double width in widths) {
        final AnatomyLayout layout = layoutAt(width);
        final double room = width - 2 * AnatomyLayout.inspectionGutter - ruler;
        expect(
          layout.columns * layout.cell,
          closeTo(room, 1e-9),
          reason: '$width',
        );
        expect(
          layout.origin.dx,
          closeTo(
            AnatomyLayout.inspectionGutter + ruler + layout.gap / 2,
            1e-9,
          ),
        );
        // One more column would take every tile under the floor.
        expect(
          room / (layout.columns + 1) * (1 - AnatomyLayout.tileGapRatio),
          lessThan(AnatomyLayout.inspectionSide),
          reason: '$width',
        );
      }
      // The iPhone 17's width, less the ruler's three digits. Thirteen at a
      // floor of twenty-five, where twenty-four bought a fourteenth column.
      expect(layoutAt(402).columns, 13);
    });

    test('it reads like text, and grooves and folds nothing', () {
      final AnatomyLayout layout = layoutAt(390);
      expect(layout.serpentine, isFalse);
      expect(layout.connectors().computeMetrics().isEmpty, isTrue);
      expect(layout.codonGap, 0);
      expect(layout.labelRows, 0);
      expect(layout.foldTo, isEmpty);
      expect(layout.origin.dy, 0);
      for (int r = 0; r < 4; r++) {
        expect(
          layout.centreOf(r * layout.columns).dx,
          closeTo(layout.centreOf(0).dx, 1e-6),
        );
      }
    });

    test('a tap finds the base under it, and nothing else is a base', () {
      for (final double width in widths) {
        final AnatomyLayout layout = layoutAt(width);
        for (int i = 0; i < dna.count; i++) {
          expect(
            layout.hitTest(layout.centreOf(i)),
            i,
            reason: 'cell $i at $width',
          );
        }
        const double gutter = AnatomyLayout.inspectionGutter;
        final Offset first = layout.centreOf(0);
        final Offset last = layout.centreOf(dna.count - 1);
        expect(layout.hitTest(Offset(gutter / 2, first.dy)), -1);
        expect(layout.hitTest(Offset(width - gutter / 2, first.dy)), -1);
        expect(layout.hitTest(last.translate(layout.cell, 0)), -1);
        expect(layout.hitTest(last.translate(0, layout.cell)), -1);
      }
    });

    // The C-peptide: 93 bases in two pieces, read in threes across the intron
    // that splits them.
    final AnatomyStage gene = model.stages.first;
    final AnatomyStage coding = AnatomySelection.of(
      model,
      gene.positionAt(
        gene.runs.firstWhere((StageRun run) => run.label == 'C-peptide').start,
      ),
    ).stage;

    AnatomyLayout codingAt(double width) =>
        AnatomyLayout.forStage(coding, Size(width, 700), Size(width, 700));

    test('only a region that is translated is read in threes', () {
      expect(dna.blocks.single.framed, isFalse);
      expect(coding.blocks.single.framed, isTrue);
      expect(coding.count, 93);
    });

    test('a coding region fits whole codons and their grooves across', () {
      for (final double width in widths) {
        final AnatomyLayout layout = codingAt(width);
        final double room = width -
            2 * AnatomyLayout.inspectionGutter -
            AnatomyRuler.gutterFor(coding);
        expect(layout.columns % 3, 0, reason: '$width');
        expect(
          layout.size.width + layout.gap,
          closeTo(room, 1e-9),
          reason: '$width',
        );
        expect(layout.side, greaterThan(AnatomyLayout.baseSide));
        // Near it, not at it. The fit is a staircase of whole codons, so how
        // close a row can come to the target is bounded by the step and not by
        // a point: on the smallest phone here the choice is 21.7 or 29.3.
        expect(
          (layout.side - AnatomyLayout.inspectionSide).abs(),
          lessThan(4),
          reason: '$width',
        );
      }
      // The grooves cost each tile a point rather than each row a codon.
      expect(codingAt(402).columns, 15);
    });

    test('its codons land flush and part across and down as they form', () {
      final AnatomyLayout open = codingAt(402);
      final AnatomyLayout flush = open.opened(0);
      final AnatomyLayout half = open.opened(0.5);
      final int columns = open.columns;
      double across(AnatomyLayout layout, int i) =>
          layout.centreOf(i + 1).dx - layout.centreOf(i).dx;
      double down(AnatomyLayout layout, int i) =>
          layout.centreOf(i + columns).dy - layout.centreOf(i).dy;

      expect(across(flush, 2), closeTo(open.cell, 1e-6));
      expect(down(flush, 0), closeTo(open.rowHeight, 1e-6));

      expect(across(open, 1), closeTo(open.cell, 1e-6));
      expect(
        across(open, 2),
        closeTo(open.cell + AnatomyLayout.codonSplit, 1e-6),
      );
      expect(
        down(open, 0),
        closeTo(open.rowHeight + AnatomyLayout.codonRise, 1e-6),
      );
      expect(
        down(half, 0),
        closeTo(open.rowHeight + AnatomyLayout.codonRise / 2, 1e-6),
      );

      // The rows part into room already reserved: the page never resizes.
      expect(flush.size, open.size);
      expect(
        open.centreOf(coding.count - 1).dy + open.rowPitchOf(0) / 2,
        lessThanOrEqualTo(open.size.height + 1e-6),
      );
    });

    test('a tap finds the base under it while its codons form', () {
      final AnatomyLayout open = codingAt(390);
      for (final double t in <double>[0, 0.3, 0.5, 0.8, 1]) {
        final AnatomyLayout layout = open.opened(t);
        for (int i = 0; i < coding.count; i++) {
          expect(layout.hitTest(layout.centreOf(i)), i, reason: 'cell $i at $t');
        }
      }
    });
  });
}
