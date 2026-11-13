import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';

/// One protein of the backend's census (`pipeline/locus/survey.py --gff`):
/// its row, as far as the zoom reads it, its `locus` track from
/// `<directory>/locus/<slug>_locus.json`, and the record the census made for
/// it from MANE's own exons, `<directory>/records/<slug>_record.json`. Null
/// where the census made no record: a gene whose exons alone are over the
/// gene page's budget, which the resolver refuses to build.
(ProteinTarget, LocusTrack, GeneRecord)? catalogued(
  String directory,
  String slug,
) {
  final File record = File('$directory/records/${slug}_record.json');
  if (!record.existsSync()) {
    return null;
  }
  final Map<String, dynamic> json = jsonDecode(
    File('$directory/locus/${slug}_locus.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final ProteinTarget target = ProteinTarget.fromJson(<String, dynamic>{
    'slug': slug,
    'display': json['gene'],
    'gene': json['gene'],
    'uniprot': json['uniprot'],
    'accession': json['sequence'],
    'summary': '',
    'facts': <String, int>{
      'residues': 0,
      'exons': 0,
      'chains': 0,
      'bridges': 0,
    },
    'catalog_order': null,
    'chain': null,
    'chains': <dynamic>[],
    'structure': null,
    'tracks': <String, String>{'record': 'ready', 'locus': 'ready'},
  });
  return (
    target,
    LocusTrack.fromJson(json, target),
    GeneRecordDto.fromJson(
      jsonDecode(record.readAsStringSync()) as Map<String, dynamic>,
    ).toEntity(),
  );
}
