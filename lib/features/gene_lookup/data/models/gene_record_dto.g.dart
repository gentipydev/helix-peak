// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gene_record_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SegmentDto _$SegmentDtoFromJson(Map<String, dynamic> json) => SegmentDto(
  start: (json['start'] as num).toInt(),
  end: (json['end'] as num).toInt(),
);

Map<String, dynamic> _$SegmentDtoToJson(SegmentDto instance) =>
    <String, dynamic>{'start': instance.start, 'end': instance.end};

LocationDto _$LocationDtoFromJson(Map<String, dynamic> json) => LocationDto(
  start: (json['start'] as num).toInt(),
  end: (json['end'] as num).toInt(),
  strand: (json['strand'] as num?)?.toInt(),
);

Map<String, dynamic> _$LocationDtoToJson(LocationDto instance) =>
    <String, dynamic>{
      'start': instance.start,
      'end': instance.end,
      'strand': instance.strand,
    };

ExonDto _$ExonDtoFromJson(Map<String, dynamic> json) => ExonDto(
  start: (json['start'] as num).toInt(),
  end: (json['end'] as num).toInt(),
  number: (json['number'] as num?)?.toInt(),
);

Map<String, dynamic> _$ExonDtoToJson(ExonDto instance) => <String, dynamic>{
  'number': instance.number,
  'start': instance.start,
  'end': instance.end,
};

PeptideDto _$PeptideDtoFromJson(Map<String, dynamic> json) => PeptideDto(
  translation: json['translation'] as String,
  product: json['product'] as String?,
  segments:
      (json['segments'] as List<dynamic>?)
          ?.map((e) => SegmentDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SegmentDto>[],
);

Map<String, dynamic> _$PeptideDtoToJson(PeptideDto instance) =>
    <String, dynamic>{
      'product': instance.product,
      'segments': instance.segments,
      'translation': instance.translation,
    };

TranscriptDto _$TranscriptDtoFromJson(Map<String, dynamic> json) =>
    TranscriptDto(
      segments:
          (json['segments'] as List<dynamic>?)
              ?.map((e) => SegmentDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SegmentDto>[],
    );

Map<String, dynamic> _$TranscriptDtoToJson(TranscriptDto instance) =>
    <String, dynamic>{'segments': instance.segments};

ProteinDto _$ProteinDtoFromJson(Map<String, dynamic> json) => ProteinDto(
  translation: json['translation'] as String,
  product: json['product'] as String?,
  segments:
      (json['segments'] as List<dynamic>?)
          ?.map((e) => SegmentDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SegmentDto>[],
);

Map<String, dynamic> _$ProteinDtoToJson(ProteinDto instance) =>
    <String, dynamic>{
      'product': instance.product,
      'translation': instance.translation,
      'segments': instance.segments,
    };

GeneRecordDto _$GeneRecordDtoFromJson(Map<String, dynamic> json) =>
    GeneRecordDto(
      gene: json['gene'] as String,
      location: LocationDto.fromJson(json['location'] as Map<String, dynamic>),
      sequence: json['sequence'] as String,
      transcript: json['transcript'] == null
          ? null
          : TranscriptDto.fromJson(json['transcript'] as Map<String, dynamic>),
      protein: json['protein'] == null
          ? null
          : ProteinDto.fromJson(json['protein'] as Map<String, dynamic>),
      exons:
          (json['exons'] as List<dynamic>?)
              ?.map((e) => ExonDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ExonDto>[],
      signalPeptide: json['signal_peptide'] == null
          ? null
          : PeptideDto.fromJson(json['signal_peptide'] as Map<String, dynamic>),
      proprotein: json['proprotein'] == null
          ? null
          : PeptideDto.fromJson(json['proprotein'] as Map<String, dynamic>),
      peptides:
          (json['peptides'] as List<dynamic>?)
              ?.map((e) => PeptideDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PeptideDto>[],
      intronScale: (json['intron_scale'] as num?)?.toDouble(),
      realSpanBp: (json['real_span_bp'] as num?)?.toInt(),
      realIntronBp: (json['real_intron_bp'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$GeneRecordDtoToJson(GeneRecordDto instance) =>
    <String, dynamic>{
      'gene': instance.gene,
      'location': instance.location,
      'sequence': instance.sequence,
      'transcript': instance.transcript,
      'protein': instance.protein,
      'exons': instance.exons,
      'signal_peptide': instance.signalPeptide,
      'proprotein': instance.proprotein,
      'peptides': instance.peptides,
      'intron_scale': instance.intronScale,
      'real_span_bp': instance.realSpanBp,
      'real_intron_bp': instance.realIntronBp,
    };
