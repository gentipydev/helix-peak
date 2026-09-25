import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_source.dart';
import '../../domain/entities/gene_query.dart';
import '../../domain/entities/protein_track.dart';
import '../models/gene_record_dto.dart';

abstract interface class GeneRemoteDataSource {
  Future<GeneRecordDto> fetchGene(GeneQuery query);
}

/// The gene record as a stored track, read like every other track the walk
/// reads.
///
/// It used to be parsed out of GenBank per request by `/gene/{id}/{gene}`,
/// which takes a record's first mRNA and CDS and cannot fetch a chromosome
/// slice -- so oxytocin, relaxin, glucagon and amylase, all four read from
/// slices, never walked on a live build. The stored record is the one the bake
/// wrote and `check_assets.py` checked, every isoform choice and shortened
/// intron included, and a record for a protein built on demand will be stored
/// the same way.
final class TrackGeneDataSource implements GeneRemoteDataSource {
  const TrackGeneDataSource(this._tracks);

  final TrackSource _tracks;

  @override
  Future<GeneRecordDto> fetchGene(GeneQuery query) async {
    final Uint8List bytes;
    try {
      bytes = await _tracks.read(query.slug, TrackKind.record);
    } on TrackApiException {
      // Every protein the app can open has its record; one that has not is a
      // row that got ahead of its bake, and the walk has nothing to draw.
      throw ServerApiException(
        statusCode: 404,
        detail: 'The gene record for ${query.gene} is not available yet.',
      );
    }
    // Decoded here rather than on another isolate, unlike the tracks: the
    // largest record is dystrophin's 52 KB, about a millisecond of work, and a
    // `compute` hop would cost more than it saves -- and never completes under
    // a widget test's fake async, where the walk's own tests load records.
    return GeneRecordDto.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}

/// The record parsed out of GenBank by the backend's `/gene/{id}/{gene}`.
///
/// No longer what the walk reads (see [TrackGeneDataSource]). Kept for the
/// fixture server's own tests and the live check of that route, which stays
/// on the backend until it is retired.
final class GeneRemoteDataSourceImpl implements GeneRemoteDataSource {
  const GeneRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<GeneRecordDto> fetchGene(GeneQuery query) async {
    final Map<String, dynamic> json = await _client.getJson(
      '/gene/${query.accession}/${query.gene}',
    );
    return GeneRecordDto.fromJson(json);
  }
}
