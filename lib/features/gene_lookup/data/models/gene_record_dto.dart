import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/gene_record.dart';

part 'gene_record_dto.g.dart';

/// Mirrors the backend's `GET /gene/{id}/{gene}` payload.
///
/// The API is snake_case, so every model here renames rather than annotating
/// each field individually.
@JsonSerializable(fieldRename: FieldRename.snake)
class SegmentDto {
  const SegmentDto({required this.start, required this.end});

  factory SegmentDto.fromJson(Map<String, dynamic> json) =>
      _$SegmentDtoFromJson(json);

  final int start;
  final int end;

  Map<String, dynamic> toJson() => _$SegmentDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class LocationDto {
  const LocationDto({required this.start, required this.end, this.strand});

  factory LocationDto.fromJson(Map<String, dynamic> json) =>
      _$LocationDtoFromJson(json);

  final int start;
  final int end;
  final int? strand;

  Map<String, dynamic> toJson() => _$LocationDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ExonDto {
  const ExonDto({required this.start, required this.end, this.number});

  factory ExonDto.fromJson(Map<String, dynamic> json) =>
      _$ExonDtoFromJson(json);

  final int? number;
  final int start;
  final int end;

  Map<String, dynamic> toJson() => _$ExonDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class PeptideDto {
  const PeptideDto({
    required this.translation,
    this.product,
    this.segments = const <SegmentDto>[],
  });

  factory PeptideDto.fromJson(Map<String, dynamic> json) =>
      _$PeptideDtoFromJson(json);

  final String? product;
  final List<SegmentDto> segments;
  final String translation;

  Map<String, dynamic> toJson() => _$PeptideDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TranscriptDto {
  const TranscriptDto({this.segments = const <SegmentDto>[]});

  factory TranscriptDto.fromJson(Map<String, dynamic> json) =>
      _$TranscriptDtoFromJson(json);

  final List<SegmentDto> segments;

  Map<String, dynamic> toJson() => _$TranscriptDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProteinDto {
  const ProteinDto({
    required this.translation,
    this.product,
    this.segments = const <SegmentDto>[],
  });

  factory ProteinDto.fromJson(Map<String, dynamic> json) =>
      _$ProteinDtoFromJson(json);

  final String? product;
  final String translation;
  final List<SegmentDto> segments;

  Map<String, dynamic> toJson() => _$ProteinDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class GeneRecordDto {
  const GeneRecordDto({
    required this.gene,
    required this.location,
    required this.sequence,
    this.transcript,
    this.protein,
    this.exons = const <ExonDto>[],
    this.signalPeptide,
    this.proprotein,
    this.peptides = const <PeptideDto>[],
    this.intronScale,
    this.realSpanBp,
    this.realIntronBp,
  });

  factory GeneRecordDto.fromJson(Map<String, dynamic> json) =>
      _$GeneRecordDtoFromJson(json);

  final String gene;

  final LocationDto location;
  final String sequence;

  final TranscriptDto? transcript;
  final ProteinDto? protein;
  final List<ExonDto> exons;
  final PeptideDto? signalPeptide;
  final PeptideDto? proprotein;
  final List<PeptideDto> peptides;

  /// How much of each intron this record holds, where it does not hold all of
  /// it: 1/252 for dystrophin's 2.1 megabases.
  ///
  /// Absent — and so null — for every record that is a verbatim slice of its
  /// GenBank source, which is eight of the ten this build ships. Introns are
  /// the only thing ever shortened: exons, the transcript and the protein are
  /// whole, so the only page this changes is the gene.
  final double? intronScale;

  /// What the gene really spans, when [intronScale] says this is not all of it.
  final int? realSpanBp;

  /// Each intron's real length, in transcript order, when [intronScale] says
  /// they were shortened.
  final List<int>? realIntronBp;

  Map<String, dynamic> toJson() => _$GeneRecordDtoToJson(this);
}

extension SegmentDtoMapper on SegmentDto {
  Segment toEntity() => Segment(start: start, end: end);
}

extension ExonDtoMapper on ExonDto {
  Exon toEntity() => Exon(number: number, start: start, end: end);
}

extension PeptideDtoMapper on PeptideDto {
  Peptide toEntity() => Peptide(
    product: product,
    segments: segments.map((SegmentDto s) => s.toEntity()).toList(),
    translation: translation,
  );
}

extension TranscriptDtoMapper on TranscriptDto {
  Transcript toEntity() => Transcript(
    segments: segments.map((SegmentDto s) => s.toEntity()).toList(),
  );
}

extension ProteinDtoMapper on ProteinDto {
  Protein toEntity() => Protein(
    product: product,
    translation: translation,
    segments: segments.map((SegmentDto s) => s.toEntity()).toList(),
  );
}

extension GeneRecordDtoMapper on GeneRecordDto {
  GeneRecord toEntity() => GeneRecord(
    gene: gene,
    start: location.start,
    end: location.end,
    strand: location.strand,
    sequence: sequence,
    transcript: transcript?.toEntity(),
    protein: protein?.toEntity(),
    exons: exons.map((ExonDto e) => e.toEntity()).toList(),
    signalPeptide: signalPeptide?.toEntity(),
    proprotein: proprotein?.toEntity(),
    peptides: peptides.map((PeptideDto p) => p.toEntity()).toList(),
    intronScale: intronScale,
    realSpanBp: realSpanBp,
    realIntronBp: realIntronBp,
  );
}
