// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AnalysisState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalysisState()';
}


}

/// @nodoc
class $AnalysisStateCopyWith<$Res>  {
$AnalysisStateCopyWith(AnalysisState _, $Res Function(AnalysisState) __);
}


/// Adds pattern-matching-related methods to [AnalysisState].
extension AnalysisStatePatterns on AnalysisState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AnalysisInitial value)?  initial,TResult Function( AnalysisLoading value)?  loading,TResult Function( AnalysisSuccess value)?  success,TResult Function( AnalysisFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AnalysisInitial() when initial != null:
return initial(_that);case AnalysisLoading() when loading != null:
return loading(_that);case AnalysisSuccess() when success != null:
return success(_that);case AnalysisFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AnalysisInitial value)  initial,required TResult Function( AnalysisLoading value)  loading,required TResult Function( AnalysisSuccess value)  success,required TResult Function( AnalysisFailure value)  failure,}){
final _that = this;
switch (_that) {
case AnalysisInitial():
return initial(_that);case AnalysisLoading():
return loading(_that);case AnalysisSuccess():
return success(_that);case AnalysisFailure():
return failure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AnalysisInitial value)?  initial,TResult? Function( AnalysisLoading value)?  loading,TResult? Function( AnalysisSuccess value)?  success,TResult? Function( AnalysisFailure value)?  failure,}){
final _that = this;
switch (_that) {
case AnalysisInitial() when initial != null:
return initial(_that);case AnalysisLoading() when loading != null:
return loading(_that);case AnalysisSuccess() when success != null:
return success(_that);case AnalysisFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loading,TResult Function( AnalysisResult result)?  success,TResult Function( String message)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AnalysisInitial() when initial != null:
return initial();case AnalysisLoading() when loading != null:
return loading();case AnalysisSuccess() when success != null:
return success(_that.result);case AnalysisFailure() when failure != null:
return failure(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loading,required TResult Function( AnalysisResult result)  success,required TResult Function( String message)  failure,}) {final _that = this;
switch (_that) {
case AnalysisInitial():
return initial();case AnalysisLoading():
return loading();case AnalysisSuccess():
return success(_that.result);case AnalysisFailure():
return failure(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loading,TResult? Function( AnalysisResult result)?  success,TResult? Function( String message)?  failure,}) {final _that = this;
switch (_that) {
case AnalysisInitial() when initial != null:
return initial();case AnalysisLoading() when loading != null:
return loading();case AnalysisSuccess() when success != null:
return success(_that.result);case AnalysisFailure() when failure != null:
return failure(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class AnalysisInitial implements AnalysisState {
  const AnalysisInitial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalysisState.initial()';
}


}




/// @nodoc


class AnalysisLoading implements AnalysisState {
  const AnalysisLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalysisState.loading()';
}


}




/// @nodoc


class AnalysisSuccess implements AnalysisState {
  const AnalysisSuccess(this.result);
  

 final  AnalysisResult result;

/// Create a copy of AnalysisState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalysisSuccessCopyWith<AnalysisSuccess> get copyWith => _$AnalysisSuccessCopyWithImpl<AnalysisSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisSuccess&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode => Object.hash(runtimeType,result);

@override
String toString() {
  return 'AnalysisState.success(result: $result)';
}


}

/// @nodoc
abstract mixin class $AnalysisSuccessCopyWith<$Res> implements $AnalysisStateCopyWith<$Res> {
  factory $AnalysisSuccessCopyWith(AnalysisSuccess value, $Res Function(AnalysisSuccess) _then) = _$AnalysisSuccessCopyWithImpl;
@useResult
$Res call({
 AnalysisResult result
});


$AnalysisResultCopyWith<$Res> get result;

}
/// @nodoc
class _$AnalysisSuccessCopyWithImpl<$Res>
    implements $AnalysisSuccessCopyWith<$Res> {
  _$AnalysisSuccessCopyWithImpl(this._self, this._then);

  final AnalysisSuccess _self;
  final $Res Function(AnalysisSuccess) _then;

/// Create a copy of AnalysisState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? result = null,}) {
  return _then(AnalysisSuccess(
null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as AnalysisResult,
  ));
}

/// Create a copy of AnalysisState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AnalysisResultCopyWith<$Res> get result {
  
  return $AnalysisResultCopyWith<$Res>(_self.result, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}

/// @nodoc


class AnalysisFailure implements AnalysisState {
  const AnalysisFailure(this.message);
  

 final  String message;

/// Create a copy of AnalysisState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalysisFailureCopyWith<AnalysisFailure> get copyWith => _$AnalysisFailureCopyWithImpl<AnalysisFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisFailure&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AnalysisState.failure(message: $message)';
}


}

/// @nodoc
abstract mixin class $AnalysisFailureCopyWith<$Res> implements $AnalysisStateCopyWith<$Res> {
  factory $AnalysisFailureCopyWith(AnalysisFailure value, $Res Function(AnalysisFailure) _then) = _$AnalysisFailureCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$AnalysisFailureCopyWithImpl<$Res>
    implements $AnalysisFailureCopyWith<$Res> {
  _$AnalysisFailureCopyWithImpl(this._self, this._then);

  final AnalysisFailure _self;
  final $Res Function(AnalysisFailure) _then;

/// Create a copy of AnalysisState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(AnalysisFailure(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
