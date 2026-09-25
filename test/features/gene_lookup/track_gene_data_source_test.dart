import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';

import '../../support/test_catalog.dart';

/// Answers with the record the bake wrote, and remembers what it was asked.
final class _RecordSource implements TrackSource {
  _RecordSource({this.missing = false});

  final bool missing;
  final List<(String, TrackKind)> asked = <(String, TrackKind)>[];

  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    asked.add((slug, kind));
    if (missing) {
      throw TrackApiException(slug: slug, kind: kind.wire, state: 'absent');
    }
    return File(TestCatalog.bySlug(slug)!.mockAsset).readAsBytesSync();
  }
}

void main() {
  test('reads the record as the record track of the protein it names', () async {
    final _RecordSource source = _RecordSource();
    final GeneRecordDto record = await TrackGeneDataSource(
      source,
    ).fetchGene(TestCatalog.relaxin.query);

    expect(source.asked, <(String, TrackKind)>[('relaxin', TrackKind.record)]);
    // Relaxin is read from a chromosome slice, which the backend's /gene route
    // could never fetch; the stored record is the bake's, C-peptide and all.
    expect(record.toEntity().gene, 'RLN2');
    expect(record.toEntity().sequence.length, greaterThan(0));
  });

  test('every catalog protein parses from its stored record', () async {
    final _RecordSource source = _RecordSource();
    for (final target in TestCatalog.all) {
      final GeneRecordDto record = await TrackGeneDataSource(
        source,
      ).fetchGene(target.query);
      expect(record.toEntity().gene, target.gene, reason: target.slug);
    }
  });

  test('a record that is not there says so about the gene', () async {
    await expectLater(
      TrackGeneDataSource(
        _RecordSource(missing: true),
      ).fetchGene(TestCatalog.oxytocin.query),
      throwsA(
        isA<ServerApiException>()
            .having((ServerApiException e) => e.statusCode, 'statusCode', 404)
            .having(
              (ServerApiException e) => e.userMessage,
              'userMessage',
              contains('OXT'),
            ),
      ),
    );
  });
}
