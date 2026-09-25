import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';

import '../../../support/test_catalog.dart';
import '../clinvar/gene_clinvar_test.dart' show readJson;

/// Whether motion is reduced. Pages are reached standing still; the jump under
/// test then runs with motion on, which is where jumps used to go missing —
/// every other walk test reduces motion throughout.
final ValueNotifier<bool> _still = ValueNotifier<bool>(true);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// [target]'s walk with every track injected, since the ClinVar and AVI assets
/// are too large for a widget test to load.
Future<void> _walk(WidgetTester tester, ProteinTarget target) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  _still.value = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) =>
          ValueListenableBuilder<bool>(
            valueListenable: _still,
            builder: (BuildContext context, bool still, Widget? _) =>
                MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: still),
                  child: child!,
                ),
          ),
      home: Theme(
        data: AppTheme.analysis,
        child: AnatomyScreen(
          record: GeneRecordDto.fromJson(
            readJson(target.mockAsset),
          ).toEntity(),
          target: target,
          constraint: ProteinConstraint.fromJson(
            readJson(target.constraintAsset),
            target,
          ),
          impact: GeneImpact.fromJson(readJson(target.impactAsset), target),
          clinvar: GeneClinVar.fromJson(readJson(target.clinvarAsset), target),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens About and asks it for residue [number], pumping only as long as the
/// sheet's own motion needs, so a transition already running keeps running.
Future<void> _askFor(WidgetTester tester, String gene, int number) async {
  await tester.tap(find.text(gene));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(_key('go-to-residue'), '$number');
  await tester.pump();
  await tester.ensureVisible(_key('go-to-residue-go'));
  await tester.pump();
  await tester.tap(_key('go-to-residue-go'));
  // The sheet's way out, and the frame after it that takes it off the page.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

int _open(WidgetTester tester) =>
    tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number;

void main() {
  testWidgets('a jump from the fold to the page beside it lands', (
    tester,
  ) async {
    // Haemoglobin's walk ends Protein, Fold: the page the fold turns back to
    // is a canvas built fresh, which never animates in and so never used to
    // say it had settled.
    final ProteinTarget hbb = TestCatalog.bySlug('hemoglobin')!;
    await _walk(tester, hbb);
    await tester.tap(_key('stage-Fold'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HBB'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('go-to-residue'), '6');
    await tester.pump();
    await tester.ensureVisible(_key('go-to-residue-go'));
    await tester.pumpAndSettle();
    _still.value = false;
    await tester.tap(_key('go-to-residue-go'));
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsOneWidget);
    expect(_open(tester), 6);
  });

  testWidgets('a second jump made before the first lands is the one kept', (
    tester,
  ) async {
    await _walk(tester, TestCatalog.insulin);
    await tester.tap(_key('stage-mRNA'));
    await tester.pumpAndSettle();
    _still.value = false;
    await tester.pump();
    // Residue 10 is a page away, so translation plays for 2.76 s…
    await _askFor(tester, 'INS', 10);
    await tester.pump(const Duration(milliseconds: 600));
    // …and residue 20 is asked for while it is still playing.
    await _askFor(tester, 'INS', 20);
    await tester.pumpAndSettle();
    expect(_open(tester), 20);
  });
}
