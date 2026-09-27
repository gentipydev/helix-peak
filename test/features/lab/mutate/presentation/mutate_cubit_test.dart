import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_cubit.dart';

import '../../../../support/fixture_track_source.dart';
import '../../../../support/test_catalog.dart';

MutateCubit _cubit(String slug) {
  final FixtureTrackSource tracks = FixtureTrackSource();
  return MutateCubit(
    target: TestCatalog.bySlug(slug)!,
    fetchGene: FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks))),
    tracks: tracks,
  );
}

/// Waits for the ClinVar snapshot, which is parsed on another isolate.
Future<MutateReady> _settled(MutateCubit cubit) async {
  for (int i = 0; i < 200; i++) {
    if (cubit.state case final MutateReady ready
        when ready.clinvar != ClinVarLoad.loading) {
      return ready;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('ClinVar never settled');
}

void main() {
  test('loads the record through the tracks it is given', () async {
    final MutateCubit cubit = _cubit('insulin');
    addTearDown(cubit.close);
    await cubit.load();
    final MutateReady ready = cubit.state as MutateReady;
    expect(ready.original.gene, 'INS');
    expect(ready.applied, isNull);
    expect(ready.shown, same(ready.model));
  });

  test('an edit is tried on the original, which stays; revert drops it', () async {
    final MutateCubit cubit = _cubit('insulin');
    addTearDown(cubit.close);
    await cubit.load();
    final MutateReady before = cubit.state as MutateReady;

    expect(cubit.apply(const Substitution(5368, 'C')), isNull);
    final MutateReady edited = cubit.state as MutateReady;
    expect(edited.original, same(before.original));
    expect(edited.applied!.outcome.kind, EditOutcomeKind.missense);
    expect(edited.applied!.oldBase, 'T');
    expect(edited.shown, same(edited.applied!.model));
    expect(
      edited.applied!.record.protein!.translation[48],
      'L',
      reason: 'phenylalanine 49 now reads leucine',
    );

    cubit.revert();
    final MutateReady back = cubit.state as MutateReady;
    expect(back.applied, isNull);
    expect(back.original, same(before.original));
  });

  test('a base in a shortened intron is refused, with the guard’s reason', () async {
    final MutateCubit cubit = _cubit('cftr');
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.eligibility(20000), isA<Ineligible>());
    final String? refused = cubit.apply(const Substitution(20000, 'A'));
    expect(
      refused,
      'This intron is drawn shortened, so an edit here cannot be placed on '
      'the chromosome.',
    );
    expect((cubit.state as MutateReady).applied, isNull);

    expect(cubit.eligibility(21800), isA<Eligible>());
  });

  test('ClinVar’s records of exactly the edited change are found', () async {
    final MutateCubit cubit = _cubit('insulin');
    addTearDown(cubit.close);
    await cubit.load();
    final MutateReady ready = await _settled(cubit);
    expect(ready.clinvar, ClinVarLoad.ready);
    expect(ready.evidence, isNotEmpty);

    // A single-base record whose base the guard allows editing.
    final VariantEvidence record = ready.evidence.firstWhere(
      (VariantEvidence e) =>
          e.variant.ref.length == 1 &&
          e.variant.alt.length == 1 &&
          cubit.eligibility(e.variant.position) is Eligible,
    );
    expect(ready.recordsAt(record.variant.position), contains(record));

    cubit.apply(Substitution(record.variant.position, record.variant.alt));
    final MutateReady edited = cubit.state as MutateReady;
    expect(
      edited.recordsOfEdit.map((VariantEvidence e) => e.variant.id),
      contains(record.variant.id),
    );
    expect(
      edited.recordsOfEdit.every(
        (VariantEvidence e) =>
            e.variant.position == record.variant.position &&
            e.variant.alt == record.variant.alt,
      ),
      isTrue,
    );
  });

  test('a gene with no ClinVar snapshot says so rather than loading', () async {
    final ProteinTarget withoutClinVar = TestCatalog.all.firstWhere(
      (ProteinTarget t) => !t.clinvarAvailable,
      orElse: () => TestCatalog.bySlug('insulin')!,
    );
    final MutateCubit cubit = _cubit(withoutClinVar.slug);
    addTearDown(cubit.close);
    await cubit.load();
    final MutateReady ready = cubit.state as MutateReady;
    expect(
      ready.clinvar,
      withoutClinVar.clinvarAvailable
          ? isNot(ClinVarLoad.absent)
          : ClinVarLoad.absent,
    );
  });

  group('an edit handed over from another flow', () {
    test('nothing is applied unless one is given', () async {
      final MutateCubit cubit = _cubit('insulin');
      addTearDown(cubit.close);
      expect(cubit.applying, isNull);
      await cubit.load();
      expect((cubit.state as MutateReady).applied, isNull);
    });

    test('one given is made as soon as the record lands', () async {
      final FixtureTrackSource tracks = FixtureTrackSource();
      final MutateCubit cubit = MutateCubit(
        target: TestCatalog.bySlug('insulin')!,
        fetchGene: FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks))),
        tracks: tracks,
        applying: const Substitution(5368, 'C'),
      );
      addTearDown(cubit.close);
      await cubit.load();

      final MutateReady ready = cubit.state as MutateReady;
      expect(ready.applied, isNotNull);
      expect(ready.applied!.edit.position, 5368);
      expect(ready.applied!.outcome.kind, EditOutcomeKind.missense);
      expect(ready.original.protein!.translation[48], 'F');
      expect(ready.applied!.record.protein!.translation[48], 'L');

      // And the ClinVar snapshot still arrives over the top of it.
      final MutateReady settled = await _settled(cubit);
      expect(settled.applied, isNotNull);
      expect(settled.clinvar, ClinVarLoad.ready);
    });
  });
}
