// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'camera_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CameraState {

 CameraPhase get phase; int get nowYear;/// Continuous slider year; drives the filter during a drag.
 double get year;/// Year quantized to decades, capped at [nowYear] (docs/04 §2.2).
 int get quantizedYear; CaptureMode get mode;/// Clockwise 90-degree turns to display the preview upright.
 int get quarterTurns; ThermalLevel get thermal; int get recordingElapsedMs; int? get textureId; int? get previewWidth; int? get previewHeight; String? get lastSavedPath; String? get errorMessage;
/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraStateCopyWith<CameraState> get copyWith => _$CameraStateCopyWithImpl<CameraState>(this as CameraState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.nowYear, nowYear) || other.nowYear == nowYear)&&(identical(other.year, year) || other.year == year)&&(identical(other.quantizedYear, quantizedYear) || other.quantizedYear == quantizedYear)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.quarterTurns, quarterTurns) || other.quarterTurns == quarterTurns)&&(identical(other.thermal, thermal) || other.thermal == thermal)&&(identical(other.recordingElapsedMs, recordingElapsedMs) || other.recordingElapsedMs == recordingElapsedMs)&&(identical(other.textureId, textureId) || other.textureId == textureId)&&(identical(other.previewWidth, previewWidth) || other.previewWidth == previewWidth)&&(identical(other.previewHeight, previewHeight) || other.previewHeight == previewHeight)&&(identical(other.lastSavedPath, lastSavedPath) || other.lastSavedPath == lastSavedPath)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,phase,nowYear,year,quantizedYear,mode,quarterTurns,thermal,recordingElapsedMs,textureId,previewWidth,previewHeight,lastSavedPath,errorMessage);

@override
String toString() {
  return 'CameraState(phase: $phase, nowYear: $nowYear, year: $year, quantizedYear: $quantizedYear, mode: $mode, quarterTurns: $quarterTurns, thermal: $thermal, recordingElapsedMs: $recordingElapsedMs, textureId: $textureId, previewWidth: $previewWidth, previewHeight: $previewHeight, lastSavedPath: $lastSavedPath, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $CameraStateCopyWith<$Res>  {
  factory $CameraStateCopyWith(CameraState value, $Res Function(CameraState) _then) = _$CameraStateCopyWithImpl;
@useResult
$Res call({
 CameraPhase phase, int nowYear, double year, int quantizedYear, CaptureMode mode, int quarterTurns, ThermalLevel thermal, int recordingElapsedMs, int? textureId, int? previewWidth, int? previewHeight, String? lastSavedPath, String? errorMessage
});




}
/// @nodoc
class _$CameraStateCopyWithImpl<$Res>
    implements $CameraStateCopyWith<$Res> {
  _$CameraStateCopyWithImpl(this._self, this._then);

  final CameraState _self;
  final $Res Function(CameraState) _then;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? nowYear = null,Object? year = null,Object? quantizedYear = null,Object? mode = null,Object? quarterTurns = null,Object? thermal = null,Object? recordingElapsedMs = null,Object? textureId = freezed,Object? previewWidth = freezed,Object? previewHeight = freezed,Object? lastSavedPath = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as CameraPhase,nowYear: null == nowYear ? _self.nowYear : nowYear // ignore: cast_nullable_to_non_nullable
as int,year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as double,quantizedYear: null == quantizedYear ? _self.quantizedYear : quantizedYear // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as CaptureMode,quarterTurns: null == quarterTurns ? _self.quarterTurns : quarterTurns // ignore: cast_nullable_to_non_nullable
as int,thermal: null == thermal ? _self.thermal : thermal // ignore: cast_nullable_to_non_nullable
as ThermalLevel,recordingElapsedMs: null == recordingElapsedMs ? _self.recordingElapsedMs : recordingElapsedMs // ignore: cast_nullable_to_non_nullable
as int,textureId: freezed == textureId ? _self.textureId : textureId // ignore: cast_nullable_to_non_nullable
as int?,previewWidth: freezed == previewWidth ? _self.previewWidth : previewWidth // ignore: cast_nullable_to_non_nullable
as int?,previewHeight: freezed == previewHeight ? _self.previewHeight : previewHeight // ignore: cast_nullable_to_non_nullable
as int?,lastSavedPath: freezed == lastSavedPath ? _self.lastSavedPath : lastSavedPath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CameraState].
extension CameraStatePatterns on CameraState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CameraState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CameraState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CameraState value)  $default,){
final _that = this;
switch (_that) {
case _CameraState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CameraState value)?  $default,){
final _that = this;
switch (_that) {
case _CameraState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CameraPhase phase,  int nowYear,  double year,  int quantizedYear,  CaptureMode mode,  int quarterTurns,  ThermalLevel thermal,  int recordingElapsedMs,  int? textureId,  int? previewWidth,  int? previewHeight,  String? lastSavedPath,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CameraState() when $default != null:
return $default(_that.phase,_that.nowYear,_that.year,_that.quantizedYear,_that.mode,_that.quarterTurns,_that.thermal,_that.recordingElapsedMs,_that.textureId,_that.previewWidth,_that.previewHeight,_that.lastSavedPath,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CameraPhase phase,  int nowYear,  double year,  int quantizedYear,  CaptureMode mode,  int quarterTurns,  ThermalLevel thermal,  int recordingElapsedMs,  int? textureId,  int? previewWidth,  int? previewHeight,  String? lastSavedPath,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _CameraState():
return $default(_that.phase,_that.nowYear,_that.year,_that.quantizedYear,_that.mode,_that.quarterTurns,_that.thermal,_that.recordingElapsedMs,_that.textureId,_that.previewWidth,_that.previewHeight,_that.lastSavedPath,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CameraPhase phase,  int nowYear,  double year,  int quantizedYear,  CaptureMode mode,  int quarterTurns,  ThermalLevel thermal,  int recordingElapsedMs,  int? textureId,  int? previewWidth,  int? previewHeight,  String? lastSavedPath,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _CameraState() when $default != null:
return $default(_that.phase,_that.nowYear,_that.year,_that.quantizedYear,_that.mode,_that.quarterTurns,_that.thermal,_that.recordingElapsedMs,_that.textureId,_that.previewWidth,_that.previewHeight,_that.lastSavedPath,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _CameraState extends CameraState {
  const _CameraState({required this.phase, required this.nowYear, required this.year, required this.quantizedYear, required this.mode, required this.quarterTurns, required this.thermal, required this.recordingElapsedMs, this.textureId, this.previewWidth, this.previewHeight, this.lastSavedPath, this.errorMessage}): super._();
  

@override final  CameraPhase phase;
@override final  int nowYear;
/// Continuous slider year; drives the filter during a drag.
@override final  double year;
/// Year quantized to decades, capped at [nowYear] (docs/04 §2.2).
@override final  int quantizedYear;
@override final  CaptureMode mode;
/// Clockwise 90-degree turns to display the preview upright.
@override final  int quarterTurns;
@override final  ThermalLevel thermal;
@override final  int recordingElapsedMs;
@override final  int? textureId;
@override final  int? previewWidth;
@override final  int? previewHeight;
@override final  String? lastSavedPath;
@override final  String? errorMessage;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CameraStateCopyWith<_CameraState> get copyWith => __$CameraStateCopyWithImpl<_CameraState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CameraState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.nowYear, nowYear) || other.nowYear == nowYear)&&(identical(other.year, year) || other.year == year)&&(identical(other.quantizedYear, quantizedYear) || other.quantizedYear == quantizedYear)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.quarterTurns, quarterTurns) || other.quarterTurns == quarterTurns)&&(identical(other.thermal, thermal) || other.thermal == thermal)&&(identical(other.recordingElapsedMs, recordingElapsedMs) || other.recordingElapsedMs == recordingElapsedMs)&&(identical(other.textureId, textureId) || other.textureId == textureId)&&(identical(other.previewWidth, previewWidth) || other.previewWidth == previewWidth)&&(identical(other.previewHeight, previewHeight) || other.previewHeight == previewHeight)&&(identical(other.lastSavedPath, lastSavedPath) || other.lastSavedPath == lastSavedPath)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,phase,nowYear,year,quantizedYear,mode,quarterTurns,thermal,recordingElapsedMs,textureId,previewWidth,previewHeight,lastSavedPath,errorMessage);

@override
String toString() {
  return 'CameraState(phase: $phase, nowYear: $nowYear, year: $year, quantizedYear: $quantizedYear, mode: $mode, quarterTurns: $quarterTurns, thermal: $thermal, recordingElapsedMs: $recordingElapsedMs, textureId: $textureId, previewWidth: $previewWidth, previewHeight: $previewHeight, lastSavedPath: $lastSavedPath, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$CameraStateCopyWith<$Res> implements $CameraStateCopyWith<$Res> {
  factory _$CameraStateCopyWith(_CameraState value, $Res Function(_CameraState) _then) = __$CameraStateCopyWithImpl;
@override @useResult
$Res call({
 CameraPhase phase, int nowYear, double year, int quantizedYear, CaptureMode mode, int quarterTurns, ThermalLevel thermal, int recordingElapsedMs, int? textureId, int? previewWidth, int? previewHeight, String? lastSavedPath, String? errorMessage
});




}
/// @nodoc
class __$CameraStateCopyWithImpl<$Res>
    implements _$CameraStateCopyWith<$Res> {
  __$CameraStateCopyWithImpl(this._self, this._then);

  final _CameraState _self;
  final $Res Function(_CameraState) _then;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? nowYear = null,Object? year = null,Object? quantizedYear = null,Object? mode = null,Object? quarterTurns = null,Object? thermal = null,Object? recordingElapsedMs = null,Object? textureId = freezed,Object? previewWidth = freezed,Object? previewHeight = freezed,Object? lastSavedPath = freezed,Object? errorMessage = freezed,}) {
  return _then(_CameraState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as CameraPhase,nowYear: null == nowYear ? _self.nowYear : nowYear // ignore: cast_nullable_to_non_nullable
as int,year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as double,quantizedYear: null == quantizedYear ? _self.quantizedYear : quantizedYear // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as CaptureMode,quarterTurns: null == quarterTurns ? _self.quarterTurns : quarterTurns // ignore: cast_nullable_to_non_nullable
as int,thermal: null == thermal ? _self.thermal : thermal // ignore: cast_nullable_to_non_nullable
as ThermalLevel,recordingElapsedMs: null == recordingElapsedMs ? _self.recordingElapsedMs : recordingElapsedMs // ignore: cast_nullable_to_non_nullable
as int,textureId: freezed == textureId ? _self.textureId : textureId // ignore: cast_nullable_to_non_nullable
as int?,previewWidth: freezed == previewWidth ? _self.previewWidth : previewWidth // ignore: cast_nullable_to_non_nullable
as int?,previewHeight: freezed == previewHeight ? _self.previewHeight : previewHeight // ignore: cast_nullable_to_non_nullable
as int?,lastSavedPath: freezed == lastSavedPath ? _self.lastSavedPath : lastSavedPath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
