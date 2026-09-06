// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PropertyPrediction {

 String get label; String get value; double get confidence;
/// Create a copy of PropertyPrediction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PropertyPredictionCopyWith<PropertyPrediction> get copyWith => _$PropertyPredictionCopyWithImpl<PropertyPrediction>(this as PropertyPrediction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PropertyPrediction&&(identical(other.label, label) || other.label == label)&&(identical(other.value, value) || other.value == value)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}


@override
int get hashCode => Object.hash(runtimeType,label,value,confidence);

@override
String toString() {
  return 'PropertyPrediction(label: $label, value: $value, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class $PropertyPredictionCopyWith<$Res>  {
  factory $PropertyPredictionCopyWith(PropertyPrediction value, $Res Function(PropertyPrediction) _then) = _$PropertyPredictionCopyWithImpl;
@useResult
$Res call({
 String label, String value, double confidence
});




}
/// @nodoc
class _$PropertyPredictionCopyWithImpl<$Res>
    implements $PropertyPredictionCopyWith<$Res> {
  _$PropertyPredictionCopyWithImpl(this._self, this._then);

  final PropertyPrediction _self;
  final $Res Function(PropertyPrediction) _then;

/// Create a copy of PropertyPrediction
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


/// Adds pattern-matching-related methods to [PropertyPrediction].
extension PropertyPredictionPatterns on PropertyPrediction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PropertyPrediction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PropertyPrediction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PropertyPrediction value)  $default,){
final _that = this;
switch (_that) {
case _PropertyPrediction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PropertyPrediction value)?  $default,){
final _that = this;
switch (_that) {
case _PropertyPrediction() when $default != null:
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
case _PropertyPrediction() when $default != null:
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
case _PropertyPrediction():
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
case _PropertyPrediction() when $default != null:
return $default(_that.label,_that.value,_that.confidence);case _:
  return null;

}
}

}

/// @nodoc


class _PropertyPrediction implements PropertyPrediction {
  const _PropertyPrediction({required this.label, required this.value, required this.confidence});
  

@override final  String label;
@override final  String value;
@override final  double confidence;

/// Create a copy of PropertyPrediction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PropertyPredictionCopyWith<_PropertyPrediction> get copyWith => __$PropertyPredictionCopyWithImpl<_PropertyPrediction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PropertyPrediction&&(identical(other.label, label) || other.label == label)&&(identical(other.value, value) || other.value == value)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}


@override
int get hashCode => Object.hash(runtimeType,label,value,confidence);

@override
String toString() {
  return 'PropertyPrediction(label: $label, value: $value, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class _$PropertyPredictionCopyWith<$Res> implements $PropertyPredictionCopyWith<$Res> {
  factory _$PropertyPredictionCopyWith(_PropertyPrediction value, $Res Function(_PropertyPrediction) _then) = __$PropertyPredictionCopyWithImpl;
@override @useResult
$Res call({
 String label, String value, double confidence
});




}
/// @nodoc
class __$PropertyPredictionCopyWithImpl<$Res>
    implements _$PropertyPredictionCopyWith<$Res> {
  __$PropertyPredictionCopyWithImpl(this._self, this._then);

  final _PropertyPrediction _self;
  final $Res Function(_PropertyPrediction) _then;

/// Create a copy of PropertyPrediction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? value = null,Object? confidence = null,}) {
  return _then(_PropertyPrediction(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$AnalysisResult {

 String get id; SequenceInput get input; NucleotideCounts get counts; double get meltingTemperatureCelsius; double get molecularWeightDaltons; DateTime get generatedAt; List<PropertyPrediction> get predictions;/// Non-fatal observations worth surfacing, e.g. ambiguous bases present.
 List<String> get warnings;
/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalysisResultCopyWith<AnalysisResult> get copyWith => _$AnalysisResultCopyWithImpl<AnalysisResult>(this as AnalysisResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalysisResult&&(identical(other.id, id) || other.id == id)&&(identical(other.input, input) || other.input == input)&&(identical(other.counts, counts) || other.counts == counts)&&(identical(other.meltingTemperatureCelsius, meltingTemperatureCelsius) || other.meltingTemperatureCelsius == meltingTemperatureCelsius)&&(identical(other.molecularWeightDaltons, molecularWeightDaltons) || other.molecularWeightDaltons == molecularWeightDaltons)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&const DeepCollectionEquality().equals(other.predictions, predictions)&&const DeepCollectionEquality().equals(other.warnings, warnings));
}


@override
int get hashCode => Object.hash(runtimeType,id,input,counts,meltingTemperatureCelsius,molecularWeightDaltons,generatedAt,const DeepCollectionEquality().hash(predictions),const DeepCollectionEquality().hash(warnings));

@override
String toString() {
  return 'AnalysisResult(id: $id, input: $input, counts: $counts, meltingTemperatureCelsius: $meltingTemperatureCelsius, molecularWeightDaltons: $molecularWeightDaltons, generatedAt: $generatedAt, predictions: $predictions, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class $AnalysisResultCopyWith<$Res>  {
  factory $AnalysisResultCopyWith(AnalysisResult value, $Res Function(AnalysisResult) _then) = _$AnalysisResultCopyWithImpl;
@useResult
$Res call({
 String id, SequenceInput input, NucleotideCounts counts, double meltingTemperatureCelsius, double molecularWeightDaltons, DateTime generatedAt, List<PropertyPrediction> predictions, List<String> warnings
});


$SequenceInputCopyWith<$Res> get input;$NucleotideCountsCopyWith<$Res> get counts;

}
/// @nodoc
class _$AnalysisResultCopyWithImpl<$Res>
    implements $AnalysisResultCopyWith<$Res> {
  _$AnalysisResultCopyWithImpl(this._self, this._then);

  final AnalysisResult _self;
  final $Res Function(AnalysisResult) _then;

/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? input = null,Object? counts = null,Object? meltingTemperatureCelsius = null,Object? molecularWeightDaltons = null,Object? generatedAt = null,Object? predictions = null,Object? warnings = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as SequenceInput,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as NucleotideCounts,meltingTemperatureCelsius: null == meltingTemperatureCelsius ? _self.meltingTemperatureCelsius : meltingTemperatureCelsius // ignore: cast_nullable_to_non_nullable
as double,molecularWeightDaltons: null == molecularWeightDaltons ? _self.molecularWeightDaltons : molecularWeightDaltons // ignore: cast_nullable_to_non_nullable
as double,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,predictions: null == predictions ? _self.predictions : predictions // ignore: cast_nullable_to_non_nullable
as List<PropertyPrediction>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SequenceInputCopyWith<$Res> get input {
  
  return $SequenceInputCopyWith<$Res>(_self.input, (value) {
    return _then(_self.copyWith(input: value));
  });
}/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NucleotideCountsCopyWith<$Res> get counts {
  
  return $NucleotideCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// Adds pattern-matching-related methods to [AnalysisResult].
extension AnalysisResultPatterns on AnalysisResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnalysisResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnalysisResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnalysisResult value)  $default,){
final _that = this;
switch (_that) {
case _AnalysisResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnalysisResult value)?  $default,){
final _that = this;
switch (_that) {
case _AnalysisResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  SequenceInput input,  NucleotideCounts counts,  double meltingTemperatureCelsius,  double molecularWeightDaltons,  DateTime generatedAt,  List<PropertyPrediction> predictions,  List<String> warnings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnalysisResult() when $default != null:
return $default(_that.id,_that.input,_that.counts,_that.meltingTemperatureCelsius,_that.molecularWeightDaltons,_that.generatedAt,_that.predictions,_that.warnings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  SequenceInput input,  NucleotideCounts counts,  double meltingTemperatureCelsius,  double molecularWeightDaltons,  DateTime generatedAt,  List<PropertyPrediction> predictions,  List<String> warnings)  $default,) {final _that = this;
switch (_that) {
case _AnalysisResult():
return $default(_that.id,_that.input,_that.counts,_that.meltingTemperatureCelsius,_that.molecularWeightDaltons,_that.generatedAt,_that.predictions,_that.warnings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  SequenceInput input,  NucleotideCounts counts,  double meltingTemperatureCelsius,  double molecularWeightDaltons,  DateTime generatedAt,  List<PropertyPrediction> predictions,  List<String> warnings)?  $default,) {final _that = this;
switch (_that) {
case _AnalysisResult() when $default != null:
return $default(_that.id,_that.input,_that.counts,_that.meltingTemperatureCelsius,_that.molecularWeightDaltons,_that.generatedAt,_that.predictions,_that.warnings);case _:
  return null;

}
}

}

/// @nodoc


class _AnalysisResult extends AnalysisResult {
  const _AnalysisResult({required this.id, required this.input, required this.counts, required this.meltingTemperatureCelsius, required this.molecularWeightDaltons, required this.generatedAt, final  List<PropertyPrediction> predictions = const <PropertyPrediction>[], final  List<String> warnings = const <String>[]}): _predictions = predictions,_warnings = warnings,super._();
  

@override final  String id;
@override final  SequenceInput input;
@override final  NucleotideCounts counts;
@override final  double meltingTemperatureCelsius;
@override final  double molecularWeightDaltons;
@override final  DateTime generatedAt;
 final  List<PropertyPrediction> _predictions;
@override@JsonKey() List<PropertyPrediction> get predictions {
  if (_predictions is EqualUnmodifiableListView) return _predictions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_predictions);
}

/// Non-fatal observations worth surfacing, e.g. ambiguous bases present.
 final  List<String> _warnings;
/// Non-fatal observations worth surfacing, e.g. ambiguous bases present.
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}


/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnalysisResultCopyWith<_AnalysisResult> get copyWith => __$AnalysisResultCopyWithImpl<_AnalysisResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnalysisResult&&(identical(other.id, id) || other.id == id)&&(identical(other.input, input) || other.input == input)&&(identical(other.counts, counts) || other.counts == counts)&&(identical(other.meltingTemperatureCelsius, meltingTemperatureCelsius) || other.meltingTemperatureCelsius == meltingTemperatureCelsius)&&(identical(other.molecularWeightDaltons, molecularWeightDaltons) || other.molecularWeightDaltons == molecularWeightDaltons)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&const DeepCollectionEquality().equals(other._predictions, _predictions)&&const DeepCollectionEquality().equals(other._warnings, _warnings));
}


@override
int get hashCode => Object.hash(runtimeType,id,input,counts,meltingTemperatureCelsius,molecularWeightDaltons,generatedAt,const DeepCollectionEquality().hash(_predictions),const DeepCollectionEquality().hash(_warnings));

@override
String toString() {
  return 'AnalysisResult(id: $id, input: $input, counts: $counts, meltingTemperatureCelsius: $meltingTemperatureCelsius, molecularWeightDaltons: $molecularWeightDaltons, generatedAt: $generatedAt, predictions: $predictions, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class _$AnalysisResultCopyWith<$Res> implements $AnalysisResultCopyWith<$Res> {
  factory _$AnalysisResultCopyWith(_AnalysisResult value, $Res Function(_AnalysisResult) _then) = __$AnalysisResultCopyWithImpl;
@override @useResult
$Res call({
 String id, SequenceInput input, NucleotideCounts counts, double meltingTemperatureCelsius, double molecularWeightDaltons, DateTime generatedAt, List<PropertyPrediction> predictions, List<String> warnings
});


@override $SequenceInputCopyWith<$Res> get input;@override $NucleotideCountsCopyWith<$Res> get counts;

}
/// @nodoc
class __$AnalysisResultCopyWithImpl<$Res>
    implements _$AnalysisResultCopyWith<$Res> {
  __$AnalysisResultCopyWithImpl(this._self, this._then);

  final _AnalysisResult _self;
  final $Res Function(_AnalysisResult) _then;

/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? input = null,Object? counts = null,Object? meltingTemperatureCelsius = null,Object? molecularWeightDaltons = null,Object? generatedAt = null,Object? predictions = null,Object? warnings = null,}) {
  return _then(_AnalysisResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as SequenceInput,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as NucleotideCounts,meltingTemperatureCelsius: null == meltingTemperatureCelsius ? _self.meltingTemperatureCelsius : meltingTemperatureCelsius // ignore: cast_nullable_to_non_nullable
as double,molecularWeightDaltons: null == molecularWeightDaltons ? _self.molecularWeightDaltons : molecularWeightDaltons // ignore: cast_nullable_to_non_nullable
as double,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,predictions: null == predictions ? _self._predictions : predictions // ignore: cast_nullable_to_non_nullable
as List<PropertyPrediction>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SequenceInputCopyWith<$Res> get input {
  
  return $SequenceInputCopyWith<$Res>(_self.input, (value) {
    return _then(_self.copyWith(input: value));
  });
}/// Create a copy of AnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NucleotideCountsCopyWith<$Res> get counts {
  
  return $NucleotideCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}

// dart format on
