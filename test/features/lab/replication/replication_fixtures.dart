import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';

import '../../../support/test_catalog.dart';

/// Parsed once per test file: the tests walk every record several times.
final Map<String, GeneRecord> _records = <String, GeneRecord>{};

/// [target]'s record, as the record track serves it.
GeneRecord recordOf(ProteinTarget target) => _records.putIfAbsent(
  target.slug,
  () => GeneRecordDto.fromJson(
    jsonDecode(File(target.mockAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity(),
);
