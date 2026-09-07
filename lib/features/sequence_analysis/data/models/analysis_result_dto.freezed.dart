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

 String get id; String get summary;@JsonKey(name: 'generated_at') DateTime get generatedAt;
/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalysisResultDtoCopyWith<AnalysisResultDto> get copyWith => _$AnalysisResultDtoCopyWithImpl<AnalysisResultDto>(this as AnalysisResultDto, _$identity);

  /// Serializes this AnalysisResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisResultDto&&(identical(other.id, id) || other.id == id)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,summary,generatedAt);

@override
String toString() {
  return 'AnalysisResultDto(id: $id, summary: $summary, generatedAt: $generatedAt)';
}


}

/// @nodoc
abstract mixin class $AnalysisResultDtoCopyWith<$Res>  {
  factory $AnalysisResultDtoCopyWith(AnalysisResultDto value, $Res Function(AnalysisResultDto) _then) = _$AnalysisResultDtoCopyWithImpl;
@useResult
$Res call({
 String id, String summary,@JsonKey(name: 'generated_at') DateTime generatedAt
});




}
/// @nodoc
class _$AnalysisResultDtoCopyWithImpl<$Res>
    implements $AnalysisResultDtoCopyWith<$Res> {
  _$AnalysisResultDtoCopyWithImpl(this._self, this._then);

  final AnalysisResultDto _self;
  final $Res Function(AnalysisResultDto) _then;

/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? summary = null,Object? generatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String summary, @JsonKey(name: 'generated_at')  DateTime generatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnalysisResultDto() when $default != null:
return $default(_that.id,_that.summary,_that.generatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String summary, @JsonKey(name: 'generated_at')  DateTime generatedAt)  $default,) {final _that = this;
switch (_that) {
case _AnalysisResultDto():
return $default(_that.id,_that.summary,_that.generatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String summary, @JsonKey(name: 'generated_at')  DateTime generatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AnalysisResultDto() when $default != null:
return $default(_that.id,_that.summary,_that.generatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnalysisResultDto implements AnalysisResultDto {
  const _AnalysisResultDto({required this.id, required this.summary, @JsonKey(name: 'generated_at') required this.generatedAt});
  factory _AnalysisResultDto.fromJson(Map<String, dynamic> json) => _$AnalysisResultDtoFromJson(json);

@override final  String id;
@override final  String summary;
@override@JsonKey(name: 'generated_at') final  DateTime generatedAt;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnalysisResultDto&&(identical(other.id, id) || other.id == id)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,summary,generatedAt);

@override
String toString() {
  return 'AnalysisResultDto(id: $id, summary: $summary, generatedAt: $generatedAt)';
}


}

/// @nodoc
abstract mixin class _$AnalysisResultDtoCopyWith<$Res> implements $AnalysisResultDtoCopyWith<$Res> {
  factory _$AnalysisResultDtoCopyWith(_AnalysisResultDto value, $Res Function(_AnalysisResultDto) _then) = __$AnalysisResultDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String summary,@JsonKey(name: 'generated_at') DateTime generatedAt
});




}
/// @nodoc
class __$AnalysisResultDtoCopyWithImpl<$Res>
    implements _$AnalysisResultDtoCopyWith<$Res> {
  __$AnalysisResultDtoCopyWithImpl(this._self, this._then);

  final _AnalysisResultDto _self;
  final $Res Function(_AnalysisResultDto) _then;

/// Create a copy of AnalysisResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? summary = null,Object? generatedAt = null,}) {
  return _then(_AnalysisResultDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
