import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_track.dart';

import '../../../../support/test_catalog.dart';
import '../trafficking_fixtures.dart';

void main() {
  test('every protein’s track reads, and says where it came from', () {
    for (final ProteinTarget target in TestCatalog.all) {
      final TraffickingTrack track = topologyOf(target);
      expect(track.residues, target.facts.residues, reason: target.slug);
      expect(track.release, '2026_03', reason: target.slug);
      expect(track.releaseDate, '2026-09-02', reason: target.slug);
      expect(track.retrieved, '2026-09-27', reason: target.slug);
    }
  });

  test('UniProt’s spans, as the track carries them', () {
    expect(topologyOf(TestCatalog.cftr).transmembrane, hasLength(12));
    expect(topologyOf(TestCatalog.cftr).transmembrane.first, (78, 98));
    expect(topologyOf(TestCatalog.tnf).transmembrane, <(int, int)>[(36, 56)]);
    expect(topologyOf(TestCatalog.app).transmembrane, <(int, int)>[(702, 722)]);
    for (final ProteinTarget target in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.sod1,
      TestCatalog.prion,
    ]) {
      expect(topologyOf(target).transmembrane, isEmpty, reason: target.slug);
    }
  });

  test('a track for another protein is refused', () {
    expect(
      () => TraffickingTrack.fromJson(
        readJson(traffickingAsset(TestCatalog.insulin)),
        TestCatalog.prion,
      ),
      throwsFormatException,
    );
  });

  test('a span off the chain is refused', () {
    final Map<String, dynamic> json = readJson(
      traffickingAsset(TestCatalog.cftr),
    );
    ((json['transmembrane'] as List<dynamic>).last
            as Map<String, dynamic>)['end'] =
        1481;
    expect(
      () => TraffickingTrack.fromJson(json, TestCatalog.cftr),
      throwsFormatException,
    );
  });

  test('a track of another length is refused', () {
    final Map<String, dynamic> json = readJson(
      traffickingAsset(TestCatalog.tnf),
    )..['residues'] = 234;
    expect(
      () => TraffickingTrack.fromJson(json, TestCatalog.tnf),
      throwsFormatException,
    );
  });

  test('a track that does not name its release is refused', () {
    final Map<String, dynamic> json = readJson(
      traffickingAsset(TestCatalog.insulin),
    )..remove('release');
    expect(
      () => TraffickingTrack.fromJson(json, TestCatalog.insulin),
      throwsFormatException,
    );
  });
}
