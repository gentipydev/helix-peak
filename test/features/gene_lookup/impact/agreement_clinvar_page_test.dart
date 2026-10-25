import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/core/theme/agreement_colors.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/agreement_page.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/clinvar_agreement.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/coding_evidence.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/gene_agreement.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/clinvar/clinvar_colors.dart';
import 'package:helixpeek/shared/clinvar/evidence_row.dart';
import 'package:helixpeek/shared/clinvar/evidence_sections.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';
import '../clinvar/gene_clinvar_test.dart' show snapshot;
import '../clinvar/variant_evidence_test.dart'
    show insulinConstraint, insulinImpact;

/// Insulin's page of a base's changes where ClinVar has a record at the base:
/// AVI, ESM-2 and ClinVar side by side (the user's ask, 2026-10-25). The
/// gene's numbers were read off the stored tracks by a script apart from the
/// app.

final GeneImpact _track = insulinImpact();
final ProteinConstraint _constraint = insulinConstraint();
final AnatomyModel _model = AnatomyModel.derive(
  insulin(),
  chain: TestCatalog.insulin.chain,
);
final List<VariantEvidence> _evidence = VariantEvidence.build(
  snapshot(),
  impact: _track,
  constraint: _constraint,
  nonCoding: nonCodingSections(_model),
);
final GeneAgreement _agreement = GeneAgreement.of(
  model: _model,
  impact: _track,
  constraint: _constraint,
)!;

/// c.268, Gly90's first base: one record, G90C, uncertain significance.
const int _c268 = 6278;

/// c.266, Arg89's middle base: every change a pathogenic record.
const int _c266 = 6276;

/// c.94, Gly32's first base: G32S and G32R, two classes; Cys without one.
const int _c94 = 5317;

/// c.129, Cys43's third base: a stop, a missense change and a silent one,
/// each with its record.
const int _c129 = 5352;

/// c.73, Phe25's first base: no record.
const int _c73 = 5296;

const String _compared =
    'AVI (AlphaGenome Atlas) scores each change from the DNA, ESM-2 the '
    'amino acid it makes from the protein sequence; both are ranked here '
    'among the gene’s missense substitutions.';
const String _independence =
    'ClinVar’s classifications are quoted as its snapshot gives them; they '
    'are not an independent test of either model: AVI draws on '
    'AlphaMissense, and submitters may have weighed computational '
    'predictions.';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The texts under [key], in reading order.
List<String> _texts(WidgetTester tester, String key) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.descendant(of: _key(key), matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan!.toPlainText(includePlaceholders: false),
];

/// Clinical words appear only where ClinVar is quoted.
void _noClinicalCopy(WidgetTester tester) {
  final RegExp clinical = RegExp(
    r'\b(pathogenic|dangerous|harmful|disease|safe|diagnosis|clinical)\b',
    caseSensitive: false,
  );
  final Iterable<Text> said = tester.widgetList<Text>(
    find.byElementPredicate((Element element) {
      if (element.widget is! Text) return false;
      bool page = false;
      bool quoted = false;
      element.visitAncestorElements((Element ancestor) {
        page = page || ancestor.widget is AgreementPage;
        quoted = quoted || ancestor.widget is ClinVarSourced;
        return true;
      });
      return page && !quoted;
    }),
  );
  for (final Text text in said) {
    final String words =
        text.data ?? text.textSpan!.toPlainText(includePlaceholders: false);
    expect(clinical.hasMatch(words), isFalse, reason: words);
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final String? directory = Platform.environment['SHOT_DIR'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    _key('agreement-capture'),
  );
  final ByteData? bytes = await tester.runAsync<ByteData>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return data!;
  });
  Directory(directory).createSync(recursive: true);
  File('$directory/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// The page for the base at [position] with ClinVar's records there, as the
/// walk opens it, still unless [motion].
Future<void> _pumpPage(
  WidgetTester tester,
  int position,
  String address, {
  Size size = const Size(390, 844),
  double text = 1,
  bool motion = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('agreement-capture'),
      child: MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(text),
            disableAnimations: !motion,
          ),
          child: AgreementPage(
            track: _track,
            impact: _track.at(position)!,
            coding: CodingEvidence.at(
              model: _model,
              position: position,
              track: _constraint,
            )!,
            agreement: _agreement,
            address: address,
            region: 'insulin',
            records: <VariantEvidence>[
              for (final VariantEvidence e in _evidence)
                if (e.variant.position == position) e,
            ],
            clinvar: ClinVarAgreement.of(
              agreement: _agreement,
              evidence: _evidence,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The walk with every track injected, ClinVar's too, under the app's own
/// theme with the walk's inside it, turned [pages] pages on.
Future<void> _walk(WidgetTester tester, {required int pages}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Theme(
        data: AppTheme.analysis,
        child: AnatomyScreen(
          record: insulin(),
          target: TestCatalog.insulin,
          constraint: insulinConstraint(),
          impact: insulinImpact(),
          clinvar: snapshot(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (int i = 0; i < pages; i++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
}

/// Brings a keyed widget on screen, scrolling the ClinVar list to a row it
/// has not built yet.
Future<void> _bringUp(WidgetTester tester, String key) async {
  final Finder built = find.byKey(ValueKey<String>(key), skipOffstage: false);
  if (built.evaluate().isEmpty &&
      find.byType(VariantsOverview).evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      _key(key),
      200,
      scrollable: find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.ensureVisible(built);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await _bringUp(tester, key);
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

/// Scrolls the page until [key] is built and on screen: the page's list
/// builds as it scrolls.
Future<void> _scrollTo(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    _key(key),
    200,
    scrollable: find.descendant(
      of: _key('agreement-scroll'),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AgreementPage),
      matching: find.byType(CloseButton),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('c.268: all three sources, ClinVar’s words for its one record', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpPage(tester, _c268, 'c.268');
    expect(find.text('c.268 · AVI, ESM-2 and ClinVar'), findsOneWidget);
    // The rows keep their two numbers; the one ClinVar has a record of
    // carries its mark beside what it makes and its words under the track.
    expect(_texts(tester, 'agreement-row-A'), <String>[
      'A',
      'Ser',
      '33.2',
      '−7.2',
    ]);
    expect(_texts(tester, 'agreement-row-C'), <String>[
      'C',
      'Arg',
      '31.8',
      '−8.4',
    ]);
    expect(_texts(tester, 'agreement-row-T'), <String>[
      'T',
      'Cys',
      '31.2',
      '−10.4',
      'Uncertain significance',
    ]);
    expect(
      tester.widget<ClinVarDot>(_key('agreement-mark-T')).group,
      ClinVarGroup.uncertain,
    );
    for (final String alt in <String>['A', 'C']) {
      expect(_key('agreement-mark-$alt'), findsNothing, reason: alt);
      expect(_key('agreement-clinvar-$alt'), findsNothing, reason: alt);
    }
    expect(
      find.ancestor(
        of: find.text('Uncertain significance'),
        matching: find.byType(ClinVarSourced),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ReviewStars>(
            find.descendant(
              of: _key('agreement-clinvar-T'),
              matching: find.byType(ReviewStars),
            ),
          )
          .count,
      1,
    );
    expect(
      tester.getSemantics(_key('agreement-row-T')).label,
      contains('ClinVar Uncertain significance, 1 of 4 review stars'),
    );
    // Hue is ClinVar's on this page: the two models' marks take the ink,
    // and every other colour is the walk's own.
    final ThemeData theme = Theme.of(tester.element(_key('agreement-card')));
    final AgreementColors models = theme.extension<AgreementColors>()!;
    expect(models.avi, theme.colorScheme.onSurface);
    expect(models.esm, theme.colorScheme.onSurface);
    expect(
      theme.extension<AnatomyColors>(),
      AppTheme.analysis.extension<AnatomyColors>(),
    );
    // The gene's ClinVar records on the scatter, and where each class stands.
    expect(
      tester.getSemantics(_key('agreement-scatter')).label,
      'Every missense substitution in INS, AVI Phred across and ESM-2 up, '
      'about the line where the two would rank them alike; ClinVar’s 89 '
      'missense records marked by class; marked: serine, arginine and '
      'cysteine',
    );
    expect(_texts(tester, 'agreement-clinvar-classes'), <String>[
      'ClinVar’s missense records',
      'AVI Phred',
      'ESM-2',
      'P/LP',
      '31',
      '26.9',
      '−8.6',
      'Conflicting',
      '11',
      '22.1',
      '−5.9',
      'VUS',
      '39',
      '21.3',
      '−5.6',
      'Other',
      '8',
      '29.6',
      '−8.6',
      'Every substitution',
      '687',
      '22.3',
      '−3.9',
      'medians',
    ]);
    // ClinVar's classes are its own words; the gene's row is not.
    for (final String label in <String>['P/LP', 'Conflicting', 'VUS', 'Other']) {
      expect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(ClinVarSourced),
        ),
        findsOneWidget,
        reason: label,
      );
    }
    expect(
      find.ancestor(
        of: find.text('Every substitution'),
        matching: find.byType(ClinVarSourced),
      ),
      findsNothing,
    );
    expect(
      tester.getSemantics(_key('agreement-clinvar-class-pathogenic')).label,
      'P/LP: 31 records; median AVI Phred 26.9; median ESM-2 −8.6',
    );
    expect(
      tester.getSemantics(_key('agreement-clinvar-class-all')).label,
      'Every substitution: 687 missense substitutions; median AVI Phred '
      '22.3; median ESM-2 −3.9',
    );
    // The page names its three sources, and says once what ClinVar's part is.
    await _scrollTo(tester, 'agreement-source');
    expect(_texts(tester, 'agreement-source'), <String>[
      'AlphaGenome Atlas · ESM-2 · ClinVar',
      _compared,
      _independence,
    ]);
    _noClinicalCopy(tester);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('c.266: each of the base’s three changes carries its own '
      'record, quoted', (WidgetTester tester) async {
    await _pumpPage(tester, _c266, 'c.266');
    for (final (String alt, String made, String words, int stars)
        in <(String, String, String, int)>[
          ('A', 'His', 'Pathogenic/Likely pathogenic', 2),
          ('C', 'Pro', 'Pathogenic', 0),
          ('T', 'Leu', 'Pathogenic', 0),
        ]) {
      expect(_texts(tester, 'agreement-row-$alt')[1], made, reason: alt);
      expect(_texts(tester, 'agreement-clinvar-$alt'), <String>[
        words,
      ], reason: alt);
      expect(
        tester.widget<ClinVarDot>(_key('agreement-mark-$alt')).group,
        ClinVarGroup.pathogenic,
        reason: alt,
      );
      expect(
        find.descendant(
          of: _key('agreement-clinvar-$alt'),
          matching: find.byType(ReviewStars),
        ),
        stars == 0 ? findsNothing : findsOneWidget,
        reason: alt,
      );
    }
    // Every clinical word on the page is ClinVar's own.
    _noClinicalCopy(tester);
    await _capture(tester, 'agreement-clinvar-c266');
  });

  testWidgets('c.94: two classes at one base, and a change with none', (
    WidgetTester tester,
  ) async {
    await _pumpPage(tester, _c94, 'c.94');
    expect(
      tester.widget<ClinVarDot>(_key('agreement-mark-A')).group,
      ClinVarGroup.pathogenic,
    );
    expect(_texts(tester, 'agreement-clinvar-A'), <String>[
      'Pathogenic/Likely pathogenic',
    ]);
    expect(
      tester.widget<ClinVarDot>(_key('agreement-mark-C')).group,
      ClinVarGroup.other,
    );
    expect(_texts(tester, 'agreement-clinvar-C'), <String>['not provided']);
    expect(_key('agreement-mark-T'), findsNothing);
    expect(_key('agreement-clinvar-T'), findsNothing);
    // Every row keeps the mark's room, so that the three tags stand in line.
    final double tag = tester.getTopLeft(find.text('Cys')).dx;
    expect(tester.getTopLeft(find.text('Ser')).dx, tag);
    expect(tester.getTopLeft(find.text('Arg')).dx, tag);
    _noClinicalCopy(tester);
    await _capture(tester, 'agreement-clinvar-c94');
  });

  testWidgets('c.129: a stop and a silent change carry ClinVar’s words under '
      'why only AVI applies', (WidgetTester tester) async {
    await _pumpPage(tester, _c129, 'c.129');
    expect(_texts(tester, 'agreement-row-A'), <String>[
      'A',
      'Ter',
      _texts(tester, 'agreement-row-A')[2],
      'Premature stop: only AVI applies.',
      'Likely pathogenic',
    ]);
    expect(_texts(tester, 'agreement-clinvar-G'), <String>['Likely pathogenic']);
    expect(_key('agreement-track-G'), findsOneWidget);
    expect(_texts(tester, 'agreement-row-T'), <String>[
      'T',
      '=',
      _texts(tester, 'agreement-row-T')[2],
      'Same amino acid: only AVI applies.',
      'Likely benign',
    ]);
    expect(
      tester.widget<ClinVarDot>(_key('agreement-mark-T')).group,
      ClinVarGroup.benign,
    );
    _noClinicalCopy(tester);
    await _capture(tester, 'agreement-clinvar-c129');
  });

  testWidgets('a base ClinVar has no record at keeps the two-model page', (
    WidgetTester tester,
  ) async {
    await _pumpPage(tester, _c73, 'c.73');
    expect(find.text('c.73 · AVI and ESM-2'), findsOneWidget);
    expect(
      Theme.of(tester.element(_key('agreement-card'))).extension<
        AgreementColors
      >(),
      same(AgreementColors.earth),
    );
    for (final String key in <String>[
      'agreement-mark-C',
      'agreement-mark-A',
      'agreement-mark-G',
      'agreement-clinvar-classes',
    ]) {
      expect(_key(key), findsNothing, reason: key);
    }
    await _scrollTo(tester, 'agreement-source');
    expect(_texts(tester, 'agreement-source'), <String>[
      'AlphaGenome Atlas · ESM-2',
      _compared,
    ]);
    await _capture(tester, 'agreement-clinvar-c73');
  });

  testWidgets('large type on a narrow phone stacks the class table', (
    WidgetTester tester,
  ) async {
    await _pumpPage(
      tester,
      _c268,
      'c.268',
      size: const Size(320, 568),
      text: 2,
    );
    expect(tester.takeException(), isNull);
    // Each class's two medians on a line under its name, the column cells
    // gone. The table is far down the page, which builds as it scrolls.
    await _scrollTo(tester, 'agreement-clinvar-class-all');
    expect(tester.takeException(), isNull);
    expect(_key('agreement-clinvar-avi-pathogenic'), findsNothing);
    expect(
      _texts(tester, 'agreement-clinvar-class-pathogenic'),
      <String>['P/LP', '31', 'AVI Phred 26.9   ESM-2 −8.6'],
    );
    await _capture(tester, 'agreement-clinvar-large');
  });

  testWidgets('with motion the marks travel in and the page settles', (
    WidgetTester tester,
  ) async {
    await _pumpPage(tester, _c268, 'c.268', motion: true);
    expect(find.text('c.268 · AVI, ESM-2 and ClinVar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every page lays out whole, its scatter and table included', (
    WidgetTester tester,
  ) async {
    for (final (int position, String address) in <(int, String)>[
      (_c268, 'c.268'),
      (_c266, 'c.266'),
      (_c94, 'c.94'),
      (_c129, 'c.129'),
      (_c73, 'c.73'),
    ]) {
      await _pumpPage(tester, position, address, size: const Size(390, 1900));
      expect(tester.takeException(), isNull, reason: address);
      expect(_key('agreement-source'), findsOneWidget, reason: address);
      await _capture(
        tester,
        'agreement-whole-${address.replaceFirst('.', '')}',
      );
    }
  });

  testWidgets('through the walk: the codon line opens all three, and the '
      'sheet’s record repeats none of it', (WidgetTester tester) async {
    await _walk(tester, pages: 1);
    tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(_c268);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    await tester.tap(_key('impact-note-link'));
    await tester.pumpAndSettle();
    expect(find.text('c.268 · AVI, ESM-2 and ClinVar'), findsOneWidget);
    expect(_texts(tester, 'agreement-clinvar-T'), <String>[
      'Uncertain significance',
    ]);
    expect(_key('agreement-clinvar-classes'), findsOneWidget);
    await _close(tester);
    expect(find.byType(AgreementPage), findsNothing);
    expect(find.byType(ImpactPanel), findsOneWidget);

    await tester.drag(_key('impact-panel-scroll'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('evidence-row-21118'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-21118'));
    await tester.pumpAndSettle();
    expect(_key('evidence-detail-21118'), findsOneWidget);
    for (final String gone in <String>[
      'evidence-esm-21118',
      'evidence-avi-21118',
      'evidence-reading-21118',
      'evidence-contributions-21118',
      'evidence-compare-21118',
    ]) {
      expect(_key(gone), findsNothing, reason: gone);
    }
    expect(find.text('Show contributions'), findsNothing);
    expect(_key('evidence-residue-21118'), findsOneWidget);
  });

  testWidgets('a residue sheet’s record opens its base’s page, and × returns '
      'to the sheet as it was', (WidgetTester tester) async {
    await _walk(tester, pages: 2);
    final AnatomyPainter painter =
        tester
                .widget<CustomPaint>(
                  find
                      .byWidgetPredicate(
                        (Widget w) =>
                            w is CustomPaint && w.painter is AnatomyPainter,
                      )
                      .first,
                )
                .painter!
            as AnatomyPainter;
    final Rect canvas = tester.getRect(
      find
          .byWidgetPredicate(
            (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
          )
          .first,
    );
    await tester.tapAt(canvas.topLeft + painter.scene.fromLayout.centreOf(95));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number,
      96,
    );
    await tester.ensureVisible(_key('evidence-row-13387'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-13387'));
    await tester.pumpAndSettle();
    final Finder link = _key('evidence-compare-13387');
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    expect(find.text('AVI and ESM-2 ›'), findsOneWidget);
    expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('c.287 · AVI, ESM-2 and ClinVar'), findsOneWidget);
    expect(_texts(tester, 'agreement-clinvar-A'), <String>[
      'Conflicting classifications of pathogenicity',
    ]);
    await _close(tester);
    expect(find.byType(AgreementPage), findsNothing);
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number,
      96,
    );
    expect(_key('evidence-detail-13387'), findsOneWidget);
  });

  testWidgets('a record in the ClinVar list opens its base’s page above the '
      'list; one off the protein has none', (WidgetTester tester) async {
    await _walk(tester, pages: 2);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    await _tapKey(tester, 'evidence-row-21118');
    await _tapKey(tester, 'evidence-compare-21118');
    expect(find.text('c.268 · AVI, ESM-2 and ClinVar'), findsOneWidget);
    await _close(tester);
    expect(find.byType(AgreementPage), findsNothing);
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(_key('evidence-detail-21118'), findsOneWidget);
    // An intronic record: AVI alone applies, and says so; no page to open.
    await _tapKey(tester, 'evidence-row-211186');
    expect(_key('evidence-compare-211186'), findsNothing);
    expect(find.text('Outside the protein: only AVI applies.'), findsOneWidget);
  });
}
