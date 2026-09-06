// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nucleotide_counts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NucleotideCounts {

 int get adenine; int get thymine; int get guanine; int get cytosine; int get other;
/// Create a copy of NucleotideCounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NucleotideCountsCopyWith<NucleotideCounts> get copyWith => _$NucleotideCountsCopyWithImpl<NucleotideCounts>(this as NucleotideCounts, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NucleotideCounts&&(identical(other.adenine, adenine) || other.adenine == adenine)&&(identical(other.thymine, thymine) || other.thymine == thymine)&&(identical(other.guanine, guanine) || other.guanine == guanine)&&(identical(other.cytosine, cytosine) || other.cytosine == cytosine)&&(identical(other.other, this.other) || other.other == this.other));
}


@override
int get hashCode => Object.hash(runtimeType,adenine,thymine,guanine,cytosine,other);

@override
String toString() {
  return 'NucleotideCounts(adenine: $adenine, thymine: $thymine, guanine: $guanine, cytosine: $cytosine, other: $other)';
}


}

/// @nodoc
abstract mixin class $NucleotideCountsCopyWith<$Res>  {
  factory $NucleotideCountsCopyWith(NucleotideCounts value, $Res Function(NucleotideCounts) _then) = _$NucleotideCountsCopyWithImpl;
@useResult
$Res call({
 int adenine, int thymine, int guanine, int cytosine, int other
});




}
/// @nodoc
class _$NucleotideCountsCopyWithImpl<$Res>
    implements $NucleotideCountsCopyWith<$Res> {
  _$NucleotideCountsCopyWithImpl(this._self, this._then);

  final NucleotideCounts _self;
  final $Res Function(NucleotideCounts) _then;

/// Create a copy of NucleotideCounts
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


/// Adds pattern-matching-related methods to [NucleotideCounts].
extension NucleotideCountsPatterns on NucleotideCounts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NucleotideCounts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NucleotideCounts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NucleotideCounts value)  $default,){
final _that = this;
switch (_that) {
case _NucleotideCounts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NucleotideCounts value)?  $default,){
final _that = this;
switch (_that) {
case _NucleotideCounts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int adenine,  int thymine,  int guanine,  int cytosine,  int other)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NucleotideCounts() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int adenine,  int thymine,  int guanine,  int cytosine,  int other)  $default,) {final _that = this;
switch (_that) {
case _NucleotideCounts():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int adenine,  int thymine,  int guanine,  int cytosine,  int other)?  $default,) {final _that = this;
switch (_that) {
case _NucleotideCounts() when $default != null:
return $default(_that.adenine,_that.thymine,_that.guanine,_that.cytosine,_that.other);case _:
  return null;

}
}

}

/// @nodoc


class _NucleotideCounts extends NucleotideCounts {
  const _NucleotideCounts({this.adenine = 0, this.thymine = 0, this.guanine = 0, this.cytosine = 0, this.other = 0}): super._();
  

@override@JsonKey() final  int adenine;
@override@JsonKey() final  int thymine;
@override@JsonKey() final  int guanine;
@override@JsonKey() final  int cytosine;
@override@JsonKey() final  int other;

/// Create a copy of NucleotideCounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NucleotideCountsCopyWith<_NucleotideCounts> get copyWith => __$NucleotideCountsCopyWithImpl<_NucleotideCounts>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NucleotideCounts&&(identical(other.adenine, adenine) || other.adenine == adenine)&&(identical(other.thymine, thymine) || other.thymine == thymine)&&(identical(other.guanine, guanine) || other.guanine == guanine)&&(identical(other.cytosine, cytosine) || other.cytosine == cytosine)&&(identical(other.other, this.other) || other.other == this.other));
}


@override
int get hashCode => Object.hash(runtimeType,adenine,thymine,guanine,cytosine,other);

@override
String toString() {
  return 'NucleotideCounts(adenine: $adenine, thymine: $thymine, guanine: $guanine, cytosine: $cytosine, other: $other)';
}


}

/// @nodoc
abstract mixin class _$NucleotideCountsCopyWith<$Res> implements $NucleotideCountsCopyWith<$Res> {
  factory _$NucleotideCountsCopyWith(_NucleotideCounts value, $Res Function(_NucleotideCounts) _then) = __$NucleotideCountsCopyWithImpl;
@override @useResult
$Res call({
 int adenine, int thymine, int guanine, int cytosine, int other
});




}
/// @nodoc
class __$NucleotideCountsCopyWithImpl<$Res>
    implements _$NucleotideCountsCopyWith<$Res> {
  __$NucleotideCountsCopyWithImpl(this._self, this._then);

  final _NucleotideCounts _self;
  final $Res Function(_NucleotideCounts) _then;

/// Create a copy of NucleotideCounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? adenine = null,Object? thymine = null,Object? guanine = null,Object? cytosine = null,Object? other = null,}) {
  return _then(_NucleotideCounts(
adenine: null == adenine ? _self.adenine : adenine // ignore: cast_nullable_to_non_nullable
as int,thymine: null == thymine ? _self.thymine : thymine // ignore: cast_nullable_to_non_nullable
as int,guanine: null == guanine ? _self.guanine : guanine // ignore: cast_nullable_to_non_nullable
as int,cytosine: null == cytosine ? _self.cytosine : cytosine // ignore: cast_nullable_to_non_nullable
as int,other: null == other ? _self.other : other // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
