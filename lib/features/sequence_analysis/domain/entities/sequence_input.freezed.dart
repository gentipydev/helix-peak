// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sequence_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SequenceInput {

 String get rawText;
/// Create a copy of SequenceInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SequenceInputCopyWith<SequenceInput> get copyWith => _$SequenceInputCopyWithImpl<SequenceInput>(this as SequenceInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SequenceInput&&(identical(other.rawText, rawText) || other.rawText == rawText));
}


@override
int get hashCode => Object.hash(runtimeType,rawText);

@override
String toString() {
  return 'SequenceInput(rawText: $rawText)';
}


}

/// @nodoc
abstract mixin class $SequenceInputCopyWith<$Res>  {
  factory $SequenceInputCopyWith(SequenceInput value, $Res Function(SequenceInput) _then) = _$SequenceInputCopyWithImpl;
@useResult
$Res call({
 String rawText
});




}
/// @nodoc
class _$SequenceInputCopyWithImpl<$Res>
    implements $SequenceInputCopyWith<$Res> {
  _$SequenceInputCopyWithImpl(this._self, this._then);

  final SequenceInput _self;
  final $Res Function(SequenceInput) _then;

/// Create a copy of SequenceInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rawText = null,}) {
  return _then(_self.copyWith(
rawText: null == rawText ? _self.rawText : rawText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SequenceInput].
extension SequenceInputPatterns on SequenceInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SequenceInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SequenceInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SequenceInput value)  $default,){
final _that = this;
switch (_that) {
case _SequenceInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SequenceInput value)?  $default,){
final _that = this;
switch (_that) {
case _SequenceInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String rawText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SequenceInput() when $default != null:
return $default(_that.rawText);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String rawText)  $default,) {final _that = this;
switch (_that) {
case _SequenceInput():
return $default(_that.rawText);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String rawText)?  $default,) {final _that = this;
switch (_that) {
case _SequenceInput() when $default != null:
return $default(_that.rawText);case _:
  return null;

}
}

}

/// @nodoc


class _SequenceInput implements SequenceInput {
  const _SequenceInput({required this.rawText});
  

@override final  String rawText;

/// Create a copy of SequenceInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SequenceInputCopyWith<_SequenceInput> get copyWith => __$SequenceInputCopyWithImpl<_SequenceInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SequenceInput&&(identical(other.rawText, rawText) || other.rawText == rawText));
}


@override
int get hashCode => Object.hash(runtimeType,rawText);

@override
String toString() {
  return 'SequenceInput(rawText: $rawText)';
}


}

/// @nodoc
abstract mixin class _$SequenceInputCopyWith<$Res> implements $SequenceInputCopyWith<$Res> {
  factory _$SequenceInputCopyWith(_SequenceInput value, $Res Function(_SequenceInput) _then) = __$SequenceInputCopyWithImpl;
@override @useResult
$Res call({
 String rawText
});




}
/// @nodoc
class __$SequenceInputCopyWithImpl<$Res>
    implements _$SequenceInputCopyWith<$Res> {
  __$SequenceInputCopyWithImpl(this._self, this._then);

  final _SequenceInput _self;
  final $Res Function(_SequenceInput) _then;

/// Create a copy of SequenceInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rawText = null,}) {
  return _then(_SequenceInput(
rawText: null == rawText ? _self.rawText : rawText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
