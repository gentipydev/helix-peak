// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AnalysisEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalysisEvent()';
}


}

/// @nodoc
class $AnalysisEventCopyWith<$Res>  {
$AnalysisEventCopyWith(AnalysisEvent _, $Res Function(AnalysisEvent) __);
}


/// Adds pattern-matching-related methods to [AnalysisEvent].
extension AnalysisEventPatterns on AnalysisEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AnalysisRequested value)?  requested,TResult Function( AnalysisRetried value)?  retried,TResult Function( AnalysisCleared value)?  cleared,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AnalysisRequested() when requested != null:
return requested(_that);case AnalysisRetried() when retried != null:
return retried(_that);case AnalysisCleared() when cleared != null:
return cleared(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AnalysisRequested value)  requested,required TResult Function( AnalysisRetried value)  retried,required TResult Function( AnalysisCleared value)  cleared,}){
final _that = this;
switch (_that) {
case AnalysisRequested():
return requested(_that);case AnalysisRetried():
return retried(_that);case AnalysisCleared():
return cleared(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AnalysisRequested value)?  requested,TResult? Function( AnalysisRetried value)?  retried,TResult? Function( AnalysisCleared value)?  cleared,}){
final _that = this;
switch (_that) {
case AnalysisRequested() when requested != null:
return requested(_that);case AnalysisRetried() when retried != null:
return retried(_that);case AnalysisCleared() when cleared != null:
return cleared(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String rawText)?  requested,TResult Function()?  retried,TResult Function()?  cleared,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AnalysisRequested() when requested != null:
return requested(_that.rawText);case AnalysisRetried() when retried != null:
return retried();case AnalysisCleared() when cleared != null:
return cleared();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String rawText)  requested,required TResult Function()  retried,required TResult Function()  cleared,}) {final _that = this;
switch (_that) {
case AnalysisRequested():
return requested(_that.rawText);case AnalysisRetried():
return retried();case AnalysisCleared():
return cleared();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String rawText)?  requested,TResult? Function()?  retried,TResult? Function()?  cleared,}) {final _that = this;
switch (_that) {
case AnalysisRequested() when requested != null:
return requested(_that.rawText);case AnalysisRetried() when retried != null:
return retried();case AnalysisCleared() when cleared != null:
return cleared();case _:
  return null;

}
}

}

/// @nodoc


class AnalysisRequested implements AnalysisEvent {
  const AnalysisRequested(this.rawText);
  

 final  String rawText;

/// Create a copy of AnalysisEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalysisRequestedCopyWith<AnalysisRequested> get copyWith => _$AnalysisRequestedCopyWithImpl<AnalysisRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisRequested&&(identical(other.rawText, rawText) || other.rawText == rawText));
}


@override
int get hashCode => Object.hash(runtimeType,rawText);

@override
String toString() {
  return 'AnalysisEvent.requested(rawText: $rawText)';
}


}

/// @nodoc
abstract mixin class $AnalysisRequestedCopyWith<$Res> implements $AnalysisEventCopyWith<$Res> {
  factory $AnalysisRequestedCopyWith(AnalysisRequested value, $Res Function(AnalysisRequested) _then) = _$AnalysisRequestedCopyWithImpl;
@useResult
$Res call({
 String rawText
});




}
/// @nodoc
class _$AnalysisRequestedCopyWithImpl<$Res>
    implements $AnalysisRequestedCopyWith<$Res> {
  _$AnalysisRequestedCopyWithImpl(this._self, this._then);

  final AnalysisRequested _self;
  final $Res Function(AnalysisRequested) _then;

/// Create a copy of AnalysisEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? rawText = null,}) {
  return _then(AnalysisRequested(
null == rawText ? _self.rawText : rawText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AnalysisRetried implements AnalysisEvent {
  const AnalysisRetried();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisRetried);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalysisEvent.retried()';
}


}




/// @nodoc


class AnalysisCleared implements AnalysisEvent {
  const AnalysisCleared();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisCleared);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalysisEvent.cleared()';
}


}




// dart format on
