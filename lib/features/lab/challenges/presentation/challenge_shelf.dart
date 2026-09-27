import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/network/track_client.dart';
import '../../../gene_lookup/data/models/gene_record_dto.dart';
import '../domain/challenge_materials.dart';

/// What this phone holds of one protein, for a puzzle made offline.
abstract interface class ChallengeShelf {
  Future<ProteinMaterials> materialsOf(ProteinTarget target);
}

/// The lab's own cache, read without the network ([TrackClient.held]): the
/// fold where its model is held, the sequence where the record is, and the
/// ClinVar snapshot's missense records where the snapshot is. Anything not
/// held is left out, and the round that wanted it asks from the catalog row.
final class CachedShelf implements ChallengeShelf {
  const CachedShelf(this._client);

  final TrackClient _client;

  @override
  Future<ProteinMaterials> materialsOf(ProteinTarget target) async {
    final bool fold =
        await _client.held(target.slug, TrackKind.structure) != null;

    String? sequence;
    final Uint8List? record = await _client.held(target.slug, TrackKind.record);
    if (record != null) {
      try {
        sequence = GeneRecordDto.fromJson(
          jsonDecode(utf8.decode(record)) as Map<String, dynamic>,
        ).toEntity().protein?.translation;
      } on Object {
        sequence = null;
      }
    }

    List<ReportedChange> reported = const <ReportedChange>[];
    final Uint8List? snapshot = await _client.held(
      target.slug,
      TrackKind.clinvar,
    );
    if (snapshot != null && sequence != null) {
      try {
        reported = await compute(_changes, (snapshot, target));
      } on Object {
        reported = const <ReportedChange>[];
      }
    }
    return ProteinMaterials(fold: fold, sequence: sequence, reported: reported);
  }

  static List<ReportedChange> _changes((Uint8List, ProteinTarget) file) {
    final (Uint8List bytes, ProteinTarget target) = file;
    final GeneClinVar clinvar = GeneClinVar.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      target,
    );
    return <ReportedChange>[
      for (final ClinVarVariant variant in clinvar.variants)
        ?ReportedChange.of(
          residue: variant.residue,
          proteinChange: variant.proteinChange,
          classification: variant.classification,
        ),
    ];
  }
}
