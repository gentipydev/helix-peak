import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_plan.dart';

import '../../../support/test_catalog.dart';

/// Parsed once per test file: the tests walk every record several times.
final Map<String, GeneRecord> _records = <String, GeneRecord>{};
final Map<String, ReplicationPlan> _plans = <String, ReplicationPlan>{};

/// [target]'s record, as the record track serves it.
GeneRecord recordOf(ProteinTarget target) => _records.putIfAbsent(
  target.slug,
  () => GeneRecordDto.fromJson(
    jsonDecode(File(target.mockAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity(),
);

ReplicationPlan planOf(ProteinTarget target) =>
    _plans.putIfAbsent(target.slug, () => ReplicationPlan.of(recordOf(target)));

/// The twenty whose records can be copied: every one but those whose introns
/// arrive shortened.
Iterable<ProteinTarget> get copyable => TestCatalog.all.where(
  (ProteinTarget t) => ReplicationPlan.refusal(recordOf(t)) == null,
);
