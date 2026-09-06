// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis_result_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnalysisResultDto {

 String get id;@JsonKey(name: 'sequence') String get bases;@JsonKey(name: 'sequence_type') String get sequenceType; NucleotideCountsDto get counts;@JsonKey(name: 'melting_temperature_c') double get meltingTemperatureCelsius;@JsonKey(name: 'molecular_weight_da') double get molecularWeightDaltons;@JsonKey(name: 'generated_at') DateTime get generatedAt;@JsonKey(name: 'fasta_header') String? get fastaHeader; List<PropertyPredictionDto> get predictions; List<String> get warnings;
/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalysisResultDtoCopyWith<AnalysisResultDto> get copyWith => _$AnalysisResultDtoCopyWithImpl<AnalysisResultDto>(this as AnalysisResultDto, _$identity);

  /// Serializes this AnalysisResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisResultDto&&(identical(other.id, id) || other.id == id)&&(identical(other.bases, bases) || other.bases == bases)&&(identical(other.sequenceType, sequenceType) || other.sequenceType == sequenceType)&&(identical(other.counts, counts) || other.counts == counts)&&(identical(other.meltingTemperatureCelsius, meltingTemperatureCelsius) || other.meltingTemperatureCelsius == meltingTemperatureCelsius)&&(identical(other.molecularWeightDaltons, molecularWeightDaltons) || other.molecularWeightDaltons == molecularWeightDaltons)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.fastaHeader, fastaHeader) || other.fastaHeader == fastaHeader)&&const DeepCollectionEquality().equals(other.predictions, predictions)&&const DeepCollectionEquality().equals(other.warnings, warnings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bases,sequenceType,counts,meltingTemperatureCelsius,molecularWeightDaltons,generatedAt,fastaHeader,const DeepCollectionEquality().hash(predictions),const DeepCollectionEquality().hash(warnings));

@override
String toString() {
  return 'AnalysisResultDto(id: $id, bases: $bases, sequenceType: $sequenceType, counts: $counts, meltingTemperatureCelsius: $meltingTemperatureCelsius, molecularWeightDaltons: $molecularWeightDaltons, generatedAt: $generatedAt, fastaHeader: $fastaHeader, predictions: $predictions, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class $AnalysisResultDtoCopyWith<$Res>  {
  factory $AnalysisResultDtoCopyWith(AnalysisResultDto value, $Res Function(AnalysisResultDto) _then) = _$AnalysisResultDtoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'sequence') String bases,@JsonKey(name: 'sequence_type') String sequenceType, NucleotideCountsDto counts,@JsonKey(name: 'melting_temperature_c') double meltingTemperatureCelsius,@JsonKey(name: 'molecular_weight_da') double molecularWeightDaltons,@JsonKey(name: 'generated_at') DateTime generatedAt,@JsonKey(name: 'fasta_header') String? fastaHeader, List<PropertyPredictionDto> predictions, List<String> warnings
});


$NucleotideCountsDtoCopyWith<$Res> get counts;

}
/// @nodoc
class _$AnalysisResultDtoCopyWithImpl<$Res>
    implements $AnalysisResultDtoCopyWith<$Res> {
  _$AnalysisResultDtoCopyWithImpl(this._self, this._then);

  final AnalysisResultDto _self;
  final $Res Function(AnalysisResultDto) _then;

/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bases = null,Object? sequenceType = null,Object? counts = null,Object? meltingTemperatureCelsius = null,Object? molecularWeightDaltons = null,Object? generatedAt = null,Object? fastaHeader = freezed,Object? predictions = null,Object? warnings = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bases: null == bases ? _self.bases : bases // ignore: cast_nullable_to_non_nullable
as String,sequenceType: null == sequenceType ? _self.sequenceType : sequenceType // ignore: cast_nullable_to_non_nullable
as String,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as NucleotideCountsDto,meltingTemperatureCelsius: null == meltingTemperatureCelsius ? _self.meltingTemperatureCelsius : meltingTemperatureCelsius // ignore: cast_nullable_to_non_nullable
as double,molecularWeightDaltons: null == molecularWeightDaltons ? _self.molecularWeightDaltons : molecularWeightDaltons // ignore: cast_nullable_to_non_nullable
as double,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fastaHeader: freezed == fastaHeader ? _self.fastaHeader : fastaHeader // ignore: cast_nullable_to_non_nullable
as String?,predictions: null == predictions ? _self.predictions : predictions // ignore: cast_nullable_to_non_nullable
as List<PropertyPredictionDto>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NucleotideCountsDtoCopyWith<$Res> get counts {
  
  return $NucleotideCountsDtoCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// Adds pattern-matching-related methods to [AnalysisResultDto].
extension AnalysisResultDtoPatterns on AnalysisResultDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnalysisResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnalysisResultDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnalysisResultDto value)  $default,){
final _that = this;
switch (_that) {
case _AnalysisResultDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnalysisResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _AnalysisResultDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'sequence')  String bases, @JsonKey(name: 'sequence_type')  String sequenceType,  NucleotideCountsDto counts, @JsonKey(name: 'melting_temperature_c')  double meltingTemperatureCelsius, @JsonKey(name: 'molecular_weight_da')  double molecularWeightDaltons, @JsonKey(name: 'generated_at')  DateTime generatedAt, @JsonKey(name: 'fasta_header')  String? fastaHeader,  List<PropertyPredictionDto> predictions,  List<String> warnings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnalysisResultDto() when $default != null:
return $default(_that.id,_that.bases,_that.sequenceType,_that.counts,_that.meltingTemperatureCelsius,_that.molecularWeightDaltons,_that.generatedAt,_that.fastaHeader,_that.predictions,_that.warnings);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'sequence')  String bases, @JsonKey(name: 'sequence_type')  String sequenceType,  NucleotideCountsDto counts, @JsonKey(name: 'melting_temperature_c')  double meltingTemperatureCelsius, @JsonKey(name: 'molecular_weight_da')  double molecularWeightDaltons, @JsonKey(name: 'generated_at')  DateTime generatedAt, @JsonKey(name: 'fasta_header')  String? fastaHeader,  List<PropertyPredictionDto> predictions,  List<String> warnings)  $default,) {final _that = this;
switch (_that) {
case _AnalysisResultDto():
return $default(_that.id,_that.bases,_that.sequenceType,_that.counts,_that.meltingTemperatureCelsius,_that.molecularWeightDaltons,_that.generatedAt,_that.fastaHeader,_that.predictions,_that.warnings);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'sequence')  String bases, @JsonKey(name: 'sequence_type')  String sequenceType,  NucleotideCountsDto counts, @JsonKey(name: 'melting_temperature_c')  double meltingTemperatureCelsius, @JsonKey(name: 'molecular_weight_da')  double molecularWeightDaltons, @JsonKey(name: 'generated_at')  DateTime generatedAt, @JsonKey(name: 'fasta_header')  String? fastaHeader,  List<PropertyPredictionDto> predictions,  List<String> warnings)?  $default,) {final _that = this;
switch (_that) {
case _AnalysisResultDto() when $default != null:
return $default(_that.id,_that.bases,_that.sequenceType,_that.counts,_that.meltingTemperatureCelsius,_that.molecularWeightDaltons,_that.generatedAt,_that.fastaHeader,_that.predictions,_that.warnings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnalysisResultDto implements AnalysisResultDto {
  const _AnalysisResultDto({required this.id, @JsonKey(name: 'sequence') required this.bases, @JsonKey(name: 'sequence_type') required this.sequenceType, required this.counts, @JsonKey(name: 'melting_temperature_c') required this.meltingTemperatureCelsius, @JsonKey(name: 'molecular_weight_da') required this.molecularWeightDaltons, @JsonKey(name: 'generated_at') required this.generatedAt, @JsonKey(name: 'fasta_header') this.fastaHeader, final  List<PropertyPredictionDto> predictions = const <PropertyPredictionDto>[], final  List<String> warnings = const <String>[]}): _predictions = predictions,_warnings = warnings;
  factory _AnalysisResultDto.fromJson(Map<String, dynamic> json) => _$AnalysisResultDtoFromJson(json);

@override final  String id;
@override@JsonKey(name: 'sequence') final  String bases;
@override@JsonKey(name: 'sequence_type') final  String sequenceType;
@override final  NucleotideCountsDto counts;
@override@JsonKey(name: 'melting_temperature_c') final  double meltingTemperatureCelsius;
@override@JsonKey(name: 'molecular_weight_da') final  double molecularWeightDaltons;
@override@JsonKey(name: 'generated_at') final  DateTime generatedAt;
@override@JsonKey(name: 'fasta_header') final  String? fastaHeader;
 final  List<PropertyPredictionDto> _predictions;
@override@JsonKey() List<PropertyPredictionDto> get predictions {
  if (_predictions is EqualUnmodifiableListView) return _predictions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_predictions);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}


/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnalysisResultDtoCopyWith<_AnalysisResultDto> get copyWith => __$AnalysisResultDtoCopyWithImpl<_AnalysisResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnalysisResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnalysisResultDto&&(identical(other.id, id) || other.id == id)&&(identical(other.bases, bases) || other.bases == bases)&&(identical(other.sequenceType, sequenceType) || other.sequenceType == sequenceType)&&(identical(other.counts, counts) || other.counts == counts)&&(identical(other.meltingTemperatureCelsius, meltingTemperatureCelsius) || other.meltingTemperatureCelsius == meltingTemperatureCelsius)&&(identical(other.molecularWeightDaltons, molecularWeightDaltons) || other.molecularWeightDaltons == molecularWeightDaltons)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.fastaHeader, fastaHeader) || other.fastaHeader == fastaHeader)&&const DeepCollectionEquality().equals(other._predictions, _predictions)&&const DeepCollectionEquality().equals(other._warnings, _warnings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bases,sequenceType,counts,meltingTemperatureCelsius,molecularWeightDaltons,generatedAt,fastaHeader,const DeepCollectionEquality().hash(_predictions),const DeepCollectionEquality().hash(_warnings));

@override
String toString() {
  return 'AnalysisResultDto(id: $id, bases: $bases, sequenceType: $sequenceType, counts: $counts, meltingTemperatureCelsius: $meltingTemperatureCelsius, molecularWeightDaltons: $molecularWeightDaltons, generatedAt: $generatedAt, fastaHeader: $fastaHeader, predictions: $predictions, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class _$AnalysisResultDtoCopyWith<$Res> implements $AnalysisResultDtoCopyWith<$Res> {
  factory _$AnalysisResultDtoCopyWith(_AnalysisResultDto value, $Res Function(_AnalysisResultDto) _then) = __$AnalysisResultDtoCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'sequence') String bases,@JsonKey(name: 'sequence_type') String sequenceType, NucleotideCountsDto counts,@JsonKey(name: 'melting_temperature_c') double meltingTemperatureCelsius,@JsonKey(name: 'molecular_weight_da') double molecularWeightDaltons,@JsonKey(name: 'generated_at') DateTime generatedAt,@JsonKey(name: 'fasta_header') String? fastaHeader, List<PropertyPredictionDto> predictions, List<String> warnings
});


@override $NucleotideCountsDtoCopyWith<$Res> get counts;

}
/// @nodoc
class __$AnalysisResultDtoCopyWithImpl<$Res>
    implements _$AnalysisResultDtoCopyWith<$Res> {
  __$AnalysisResultDtoCopyWithImpl(this._self, this._then);

  final _AnalysisResultDto _self;
  final $Res Function(_AnalysisResultDto) _then;

/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bases = null,Object? sequenceType = null,Object? counts = null,Object? meltingTemperatureCelsius = null,Object? molecularWeightDaltons = null,Object? generatedAt = null,Object? fastaHeader = freezed,Object? predictions = null,Object? warnings = null,}) {
  return _then(_AnalysisResultDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bases: null == bases ? _self.bases : bases // ignore: cast_nullable_to_non_nullable
as String,sequenceType: null == sequenceType ? _self.sequenceType : sequenceType // ignore: cast_nullable_to_non_nullable
as String,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as NucleotideCountsDto,meltingTemperatureCelsius: null == meltingTemperatureCelsius ? _self.meltingTemperatureCelsius : meltingTemperatureCelsius // ignore: cast_nullable_to_non_nullable
as double,molecularWeightDaltons: null == molecularWeightDaltons ? _self.molecularWeightDaltons : molecularWeightDaltons // ignore: cast_nullable_to_non_nullable
as double,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fastaHeader: freezed == fastaHeader ? _self.fastaHeader : fastaHeader // ignore: cast_nullable_to_non_nullable
as String?,predictions: null == predictions ? _self._predictions : predictions // ignore: cast_nullable_to_non_nullable
as List<PropertyPredictionDto>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NucleotideCountsDtoCopyWith<$Res> get counts {
  
  return $NucleotideCountsDtoCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// @nodoc
mixin _$NucleotideCountsDto {

@JsonKey(name: 'a') int get adenine;@JsonKey(name: 't') int get thymine;@JsonKey(name: 'g') int get guanine;@JsonKey(name: 'c') int get cytosine; int get other;
/// Create a copy of NucleotideCountsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NucleotideCountsDtoCopyWith<NucleotideCountsDto> get copyWith => _$NucleotideCountsDtoCopyWithImpl<NucleotideCountsDto>(this as NucleotideCountsDto, _$identity);

  /// Serializes this NucleotideCountsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NucleotideCountsDto&&(identical(other.adenine, adenine) || other.adenine == adenine)&&(identical(other.thymine, thymine) || other.thymine == thymine)&&(identical(other.guanine, guanine) || other.guanine == guanine)&&(identical(other.cytosine, cytosine) || other.cytosine == cytosine)&&(identical(other.other, this.other) || other.other == this.other));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,adenine,thymine,guanine,cytosine,other);

@override
String toString() {
  return 'NucleotideCountsDto(adenine: $adenine, thymine: $thymine, guanine: $guanine, cytosine: $cytosine, other: $other)';
}


}

/// @nodoc
abstract mixin class $NucleotideCountsDtoCopyWith<$Res>  {
  factory $NucleotideCountsDtoCopyWith(NucleotideCountsDto value, $Res Function(NucleotideCountsDto) _then) = _$NucleotideCountsDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'a') int adenine,@JsonKey(name: 't') int thymine,@JsonKey(name: 'g') int guanine,@JsonKey(name: 'c') int cytosine, int other
});




}
/// @nodoc
class _$NucleotideCountsDtoCopyWithImpl<$Res>
    implements $NucleotideCountsDtoCopyWith<$Res> {
  _$NucleotideCountsDtoCopyWithImpl(this._self, this._then);

  final NucleotideCountsDto _self;
  final $Res Function(NucleotideCountsDto) _then;

/// Create a copy of NucleotideCountsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? adenine = null,Object? thymine = null,Object? guanine = null,Object? cytosine = null,Object? other = null,}) {
  return _then(_self.copyWith(
adenine: null == adenine ? _self.adenine : adenine // ignore: cast_nullable_to_non_nullable
as int,thymine: null == thymine ? _self.thymine : thymine // ignore: cast_nullable_to_non_nullable
as int,guanine: null == guanine ? _self.guanine : guanine // ignore: cast_nullable_to_non_nullable
as int,cytosine: null == cytosine ? _self.cytosine : cytosine // ignore: cast_nullable_to_non_nullable
as int,other: null == other ? _self.other : other // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NucleotideCountsDto].
extension NucleotideCountsDtoPatterns on NucleotideCountsDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NucleotideCountsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NucleotideCountsDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NucleotideCountsDto value)  $default,){
final _that = this;
switch (_that) {
case _NucleotideCountsDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NucleotideCountsDto value)?  $default,){
final _that = this;
switch (_that) {
case _NucleotideCountsDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'a')  int adenine, @JsonKey(name: 't')  int thymine, @JsonKey(name: 'g')  int guanine, @JsonKey(name: 'c')  int cytosine,  int other)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NucleotideCountsDto() when $default != null:
return $default(_that.adenine,_that.thymine,_that.guanine,_that.cytosine,_that.other);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'a')  int adenine, @JsonKey(name: 't')  int thymine, @JsonKey(name: 'g')  int guanine, @JsonKey(name: 'c')  int cytosine,  int other)  $default,) {final _that = this;
switch (_that) {
case _NucleotideCountsDto():
return $default(_that.adenine,_that.thymine,_that.guanine,_that.cytosine,_that.other);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'a')  int adenine, @JsonKey(name: 't')  int thymine, @JsonKey(name: 'g')  int guanine, @JsonKey(name: 'c')  int cytosine,  int other)?  $default,) {final _that = this;
switch (_that) {
case _NucleotideCountsDto() when $default != null:
return $default(_that.adenine,_that.thymine,_that.guanine,_that.cytosine,_that.other);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NucleotideCountsDto implements NucleotideCountsDto {
  const _NucleotideCountsDto({@JsonKey(name: 'a') this.adenine = 0, @JsonKey(name: 't') this.thymine = 0, @JsonKey(name: 'g') this.guanine = 0, @JsonKey(name: 'c') this.cytosine = 0, this.other = 0});
  factory _NucleotideCountsDto.fromJson(Map<String, dynamic> json) => _$NucleotideCountsDtoFromJson(json);

@override@JsonKey(name: 'a') final  int adenine;
@override@JsonKey(name: 't') final  int thymine;
@override@JsonKey(name: 'g') final  int guanine;
@override@JsonKey(name: 'c') final  int cytosine;
@override@JsonKey() final  int other;

/// Create a copy of NucleotideCountsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NucleotideCountsDtoCopyWith<_NucleotideCountsDto> get copyWith => __$NucleotideCountsDtoCopyWithImpl<_NucleotideCountsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NucleotideCountsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NucleotideCountsDto&&(identical(other.adenine, adenine) || other.adenine == adenine)&&(identical(other.thymine, thymine) || other.thymine == thymine)&&(identical(other.guanine, guanine) || other.guanine == guanine)&&(identical(other.cytosine, cytosine) || other.cytosine == cytosine)&&(identical(other.other, this.other) || other.other == this.other));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,adenine,thymine,guanine,cytosine,other);

@override
String toString() {
  return 'NucleotideCountsDto(adenine: $adenine, thymine: $thymine, guanine: $guanine, cytosine: $cytosine, other: $other)';
}


}

/// @nodoc
abstract mixin class _$NucleotideCountsDtoCopyWith<$Res> implements $NucleotideCountsDtoCopyWith<$Res> {
  factory _$NucleotideCountsDtoCopyWith(_NucleotideCountsDto value, $Res Function(_NucleotideCountsDto) _then) = __$NucleotideCountsDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'a') int adenine,@JsonKey(name: 't') int thymine,@JsonKey(name: 'g') int guanine,@JsonKey(name: 'c') int cytosine, int other
});




}
/// @nodoc
class __$NucleotideCountsDtoCopyWithImpl<$Res>
    implements _$NucleotideCountsDtoCopyWith<$Res> {
  __$NucleotideCountsDtoCopyWithImpl(this._self, this._then);

  final _NucleotideCountsDto _self;
  final $Res Function(_NucleotideCountsDto) _then;

/// Create a copy of NucleotideCountsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? adenine = null,Object? thymine = null,Object? guanine = null,Object? cytosine = null,Object? other = null,}) {
  return _then(_NucleotideCountsDto(
adenine: null == adenine ? _self.adenine : adenine // ignore: cast_nullable_to_non_nullable
as int,thymine: null == thymine ? _self.thymine : thymine // ignore: cast_nullable_to_non_nullable
as int,guanine: null == guanine ? _self.guanine : guanine // ignore: cast_nullable_to_non_nullable
as int,cytosine: null == cytosine ? _self.cytosine : cytosine // ignore: cast_nullable_to_non_nullable
as int,other: null == other ? _self.other : other // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PropertyPredictionDto {

 String get label; String get value; double get confidence;
/// Create a copy of PropertyPredictionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PropertyPredictionDtoCopyWith<PropertyPredictionDto> get copyWith => _$PropertyPredictionDtoCopyWithImpl<PropertyPredictionDto>(this as PropertyPredictionDto, _$identity);

  /// Serializes this PropertyPredictionDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PropertyPredictionDto&&(identical(other.label, label) || other.label == label)&&(identical(other.value, value) || other.value == value)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,value,confidence);

@override
String toString() {
  return 'PropertyPredictionDto(label: $label, value: $value, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class $PropertyPredictionDtoCopyWith<$Res>  {
  factory $PropertyPredictionDtoCopyWith(PropertyPredictionDto value, $Res Function(PropertyPredictionDto) _then) = _$PropertyPredictionDtoCopyWithImpl;
@useResult
$Res call({
 String label, String value, double confidence
});




}
/// @nodoc
class _$PropertyPredictionDtoCopyWithImpl<$Res>
    implements $PropertyPredictionDtoCopyWith<$Res> {
  _$PropertyPredictionDtoCopyWithImpl(this._self, this._then);

  final PropertyPredictionDto _self;
  final $Res Function(PropertyPredictionDto) _then;

/// Create a copy of PropertyPredictionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? value = null,Object? confidence = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PropertyPredictionDto].
extension PropertyPredictionDtoPatterns on PropertyPredictionDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PropertyPredictionDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PropertyPredictionDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PropertyPredictionDto value)  $default,){
final _that = this;
switch (_that) {
case _PropertyPredictionDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PropertyPredictionDto value)?  $default,){
final _that = this;
switch (_that) {
case _PropertyPredictionDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  String value,  double confidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PropertyPredictionDto() when $default != null:
return $default(_that.label,_that.value,_that.confidence);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  String value,  double confidence)  $default,) {final _that = this;
switch (_that) {
case _PropertyPredictionDto():
return $default(_that.label,_that.value,_that.confidence);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  String value,  double confidence)?  $default,) {final _that = this;
switch (_that) {
case _PropertyPredictionDto() when $default != null:
return $default(_that.label,_that.value,_that.confidence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PropertyPredictionDto implements PropertyPredictionDto {
  const _PropertyPredictionDto({required this.label, required this.value, required this.confidence});
  factory _PropertyPredictionDto.fromJson(Map<String, dynamic> json) => _$PropertyPredictionDtoFromJson(json);

@override final  String label;
@override final  String value;
@override final  double confidence;

/// Create a copy of PropertyPredictionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PropertyPredictionDtoCopyWith<_PropertyPredictionDto> get copyWith => __$PropertyPredictionDtoCopyWithImpl<_PropertyPredictionDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PropertyPredictionDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PropertyPredictionDto&&(identical(other.label, label) || other.label == label)&&(identical(other.value, value) || other.value == value)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,value,confidence);

@override
String toString() {
  return 'PropertyPredictionDto(label: $label, value: $value, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class _$PropertyPredictionDtoCopyWith<$Res> implements $PropertyPredictionDtoCopyWith<$Res> {
  factory _$PropertyPredictionDtoCopyWith(_PropertyPredictionDto value, $Res Function(_PropertyPredictionDto) _then) = __$PropertyPredictionDtoCopyWithImpl;
@override @useResult
$Res call({
 String label, String value, double confidence
});




}
/// @nodoc
class __$PropertyPredictionDtoCopyWithImpl<$Res>
    implements _$PropertyPredictionDtoCopyWith<$Res> {
  __$PropertyPredictionDtoCopyWithImpl(this._self, this._then);

  final _PropertyPredictionDto _self;
  final $Res Function(_PropertyPredictionDto) _then;

/// Create a copy of PropertyPredictionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? value = null,Object? confidence = null,}) {
  return _then(_PropertyPredictionDto(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
