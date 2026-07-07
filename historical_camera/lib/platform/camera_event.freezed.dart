// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'camera_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CameraEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent()';
}


}

/// @nodoc
class $CameraEventCopyWith<$Res>  {
$CameraEventCopyWith(CameraEvent _, $Res Function(CameraEvent) __);
}


/// Adds pattern-matching-related methods to [CameraEvent].
extension CameraEventPatterns on CameraEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CameraInitializedEvent value)?  initialized,TResult Function( OrientationChangedEvent value)?  orientationChanged,TResult Function( PhotoSavedEvent value)?  photoSaved,TResult Function( ThermalEvent value)?  thermal,TResult Function( RecordingProgressEvent value)?  recordingProgress,TResult Function( DebugStatsEvent value)?  debugStats,TResult Function( CameraErrorEvent value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CameraInitializedEvent() when initialized != null:
return initialized(_that);case OrientationChangedEvent() when orientationChanged != null:
return orientationChanged(_that);case PhotoSavedEvent() when photoSaved != null:
return photoSaved(_that);case ThermalEvent() when thermal != null:
return thermal(_that);case RecordingProgressEvent() when recordingProgress != null:
return recordingProgress(_that);case DebugStatsEvent() when debugStats != null:
return debugStats(_that);case CameraErrorEvent() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CameraInitializedEvent value)  initialized,required TResult Function( OrientationChangedEvent value)  orientationChanged,required TResult Function( PhotoSavedEvent value)  photoSaved,required TResult Function( ThermalEvent value)  thermal,required TResult Function( RecordingProgressEvent value)  recordingProgress,required TResult Function( DebugStatsEvent value)  debugStats,required TResult Function( CameraErrorEvent value)  error,}){
final _that = this;
switch (_that) {
case CameraInitializedEvent():
return initialized(_that);case OrientationChangedEvent():
return orientationChanged(_that);case PhotoSavedEvent():
return photoSaved(_that);case ThermalEvent():
return thermal(_that);case RecordingProgressEvent():
return recordingProgress(_that);case DebugStatsEvent():
return debugStats(_that);case CameraErrorEvent():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CameraInitializedEvent value)?  initialized,TResult? Function( OrientationChangedEvent value)?  orientationChanged,TResult? Function( PhotoSavedEvent value)?  photoSaved,TResult? Function( ThermalEvent value)?  thermal,TResult? Function( RecordingProgressEvent value)?  recordingProgress,TResult? Function( DebugStatsEvent value)?  debugStats,TResult? Function( CameraErrorEvent value)?  error,}){
final _that = this;
switch (_that) {
case CameraInitializedEvent() when initialized != null:
return initialized(_that);case OrientationChangedEvent() when orientationChanged != null:
return orientationChanged(_that);case PhotoSavedEvent() when photoSaved != null:
return photoSaved(_that);case ThermalEvent() when thermal != null:
return thermal(_that);case RecordingProgressEvent() when recordingProgress != null:
return recordingProgress(_that);case DebugStatsEvent() when debugStats != null:
return debugStats(_that);case CameraErrorEvent() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initialized,TResult Function( int quarterTurns)?  orientationChanged,TResult Function( String path)?  photoSaved,TResult Function( ThermalLevel level)?  thermal,TResult Function( int elapsedMs)?  recordingProgress,TResult Function( double gpuMs)?  debugStats,TResult Function( String code,  String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CameraInitializedEvent() when initialized != null:
return initialized();case OrientationChangedEvent() when orientationChanged != null:
return orientationChanged(_that.quarterTurns);case PhotoSavedEvent() when photoSaved != null:
return photoSaved(_that.path);case ThermalEvent() when thermal != null:
return thermal(_that.level);case RecordingProgressEvent() when recordingProgress != null:
return recordingProgress(_that.elapsedMs);case DebugStatsEvent() when debugStats != null:
return debugStats(_that.gpuMs);case CameraErrorEvent() when error != null:
return error(_that.code,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initialized,required TResult Function( int quarterTurns)  orientationChanged,required TResult Function( String path)  photoSaved,required TResult Function( ThermalLevel level)  thermal,required TResult Function( int elapsedMs)  recordingProgress,required TResult Function( double gpuMs)  debugStats,required TResult Function( String code,  String message)  error,}) {final _that = this;
switch (_that) {
case CameraInitializedEvent():
return initialized();case OrientationChangedEvent():
return orientationChanged(_that.quarterTurns);case PhotoSavedEvent():
return photoSaved(_that.path);case ThermalEvent():
return thermal(_that.level);case RecordingProgressEvent():
return recordingProgress(_that.elapsedMs);case DebugStatsEvent():
return debugStats(_that.gpuMs);case CameraErrorEvent():
return error(_that.code,_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initialized,TResult? Function( int quarterTurns)?  orientationChanged,TResult? Function( String path)?  photoSaved,TResult? Function( ThermalLevel level)?  thermal,TResult? Function( int elapsedMs)?  recordingProgress,TResult? Function( double gpuMs)?  debugStats,TResult? Function( String code,  String message)?  error,}) {final _that = this;
switch (_that) {
case CameraInitializedEvent() when initialized != null:
return initialized();case OrientationChangedEvent() when orientationChanged != null:
return orientationChanged(_that.quarterTurns);case PhotoSavedEvent() when photoSaved != null:
return photoSaved(_that.path);case ThermalEvent() when thermal != null:
return thermal(_that.level);case RecordingProgressEvent() when recordingProgress != null:
return recordingProgress(_that.elapsedMs);case DebugStatsEvent() when debugStats != null:
return debugStats(_that.gpuMs);case CameraErrorEvent() when error != null:
return error(_that.code,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class CameraInitializedEvent implements CameraEvent {
  const CameraInitializedEvent();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraInitializedEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.initialized()';
}


}




/// @nodoc


class OrientationChangedEvent implements CameraEvent {
  const OrientationChangedEvent(this.quarterTurns);
  

 final  int quarterTurns;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrientationChangedEventCopyWith<OrientationChangedEvent> get copyWith => _$OrientationChangedEventCopyWithImpl<OrientationChangedEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrientationChangedEvent&&(identical(other.quarterTurns, quarterTurns) || other.quarterTurns == quarterTurns));
}


@override
int get hashCode => Object.hash(runtimeType,quarterTurns);

@override
String toString() {
  return 'CameraEvent.orientationChanged(quarterTurns: $quarterTurns)';
}


}

/// @nodoc
abstract mixin class $OrientationChangedEventCopyWith<$Res> implements $CameraEventCopyWith<$Res> {
  factory $OrientationChangedEventCopyWith(OrientationChangedEvent value, $Res Function(OrientationChangedEvent) _then) = _$OrientationChangedEventCopyWithImpl;
@useResult
$Res call({
 int quarterTurns
});




}
/// @nodoc
class _$OrientationChangedEventCopyWithImpl<$Res>
    implements $OrientationChangedEventCopyWith<$Res> {
  _$OrientationChangedEventCopyWithImpl(this._self, this._then);

  final OrientationChangedEvent _self;
  final $Res Function(OrientationChangedEvent) _then;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? quarterTurns = null,}) {
  return _then(OrientationChangedEvent(
null == quarterTurns ? _self.quarterTurns : quarterTurns // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class PhotoSavedEvent implements CameraEvent {
  const PhotoSavedEvent(this.path);
  

 final  String path;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoSavedEventCopyWith<PhotoSavedEvent> get copyWith => _$PhotoSavedEventCopyWithImpl<PhotoSavedEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoSavedEvent&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'CameraEvent.photoSaved(path: $path)';
}


}

/// @nodoc
abstract mixin class $PhotoSavedEventCopyWith<$Res> implements $CameraEventCopyWith<$Res> {
  factory $PhotoSavedEventCopyWith(PhotoSavedEvent value, $Res Function(PhotoSavedEvent) _then) = _$PhotoSavedEventCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$PhotoSavedEventCopyWithImpl<$Res>
    implements $PhotoSavedEventCopyWith<$Res> {
  _$PhotoSavedEventCopyWithImpl(this._self, this._then);

  final PhotoSavedEvent _self;
  final $Res Function(PhotoSavedEvent) _then;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(PhotoSavedEvent(
null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ThermalEvent implements CameraEvent {
  const ThermalEvent(this.level);
  

 final  ThermalLevel level;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThermalEventCopyWith<ThermalEvent> get copyWith => _$ThermalEventCopyWithImpl<ThermalEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThermalEvent&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode => Object.hash(runtimeType,level);

@override
String toString() {
  return 'CameraEvent.thermal(level: $level)';
}


}

/// @nodoc
abstract mixin class $ThermalEventCopyWith<$Res> implements $CameraEventCopyWith<$Res> {
  factory $ThermalEventCopyWith(ThermalEvent value, $Res Function(ThermalEvent) _then) = _$ThermalEventCopyWithImpl;
@useResult
$Res call({
 ThermalLevel level
});




}
/// @nodoc
class _$ThermalEventCopyWithImpl<$Res>
    implements $ThermalEventCopyWith<$Res> {
  _$ThermalEventCopyWithImpl(this._self, this._then);

  final ThermalEvent _self;
  final $Res Function(ThermalEvent) _then;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? level = null,}) {
  return _then(ThermalEvent(
null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as ThermalLevel,
  ));
}


}

/// @nodoc


class RecordingProgressEvent implements CameraEvent {
  const RecordingProgressEvent(this.elapsedMs);
  

 final  int elapsedMs;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecordingProgressEventCopyWith<RecordingProgressEvent> get copyWith => _$RecordingProgressEventCopyWithImpl<RecordingProgressEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecordingProgressEvent&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs));
}


@override
int get hashCode => Object.hash(runtimeType,elapsedMs);

@override
String toString() {
  return 'CameraEvent.recordingProgress(elapsedMs: $elapsedMs)';
}


}

/// @nodoc
abstract mixin class $RecordingProgressEventCopyWith<$Res> implements $CameraEventCopyWith<$Res> {
  factory $RecordingProgressEventCopyWith(RecordingProgressEvent value, $Res Function(RecordingProgressEvent) _then) = _$RecordingProgressEventCopyWithImpl;
@useResult
$Res call({
 int elapsedMs
});




}
/// @nodoc
class _$RecordingProgressEventCopyWithImpl<$Res>
    implements $RecordingProgressEventCopyWith<$Res> {
  _$RecordingProgressEventCopyWithImpl(this._self, this._then);

  final RecordingProgressEvent _self;
  final $Res Function(RecordingProgressEvent) _then;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? elapsedMs = null,}) {
  return _then(RecordingProgressEvent(
null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class DebugStatsEvent implements CameraEvent {
  const DebugStatsEvent(this.gpuMs);
  

 final  double gpuMs;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DebugStatsEventCopyWith<DebugStatsEvent> get copyWith => _$DebugStatsEventCopyWithImpl<DebugStatsEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DebugStatsEvent&&(identical(other.gpuMs, gpuMs) || other.gpuMs == gpuMs));
}


@override
int get hashCode => Object.hash(runtimeType,gpuMs);

@override
String toString() {
  return 'CameraEvent.debugStats(gpuMs: $gpuMs)';
}


}

/// @nodoc
abstract mixin class $DebugStatsEventCopyWith<$Res> implements $CameraEventCopyWith<$Res> {
  factory $DebugStatsEventCopyWith(DebugStatsEvent value, $Res Function(DebugStatsEvent) _then) = _$DebugStatsEventCopyWithImpl;
@useResult
$Res call({
 double gpuMs
});




}
/// @nodoc
class _$DebugStatsEventCopyWithImpl<$Res>
    implements $DebugStatsEventCopyWith<$Res> {
  _$DebugStatsEventCopyWithImpl(this._self, this._then);

  final DebugStatsEvent _self;
  final $Res Function(DebugStatsEvent) _then;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? gpuMs = null,}) {
  return _then(DebugStatsEvent(
null == gpuMs ? _self.gpuMs : gpuMs // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class CameraErrorEvent implements CameraEvent {
  const CameraErrorEvent(this.code, this.message);
  

 final  String code;
 final  String message;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraErrorEventCopyWith<CameraErrorEvent> get copyWith => _$CameraErrorEventCopyWithImpl<CameraErrorEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraErrorEvent&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,code,message);

@override
String toString() {
  return 'CameraEvent.error(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class $CameraErrorEventCopyWith<$Res> implements $CameraEventCopyWith<$Res> {
  factory $CameraErrorEventCopyWith(CameraErrorEvent value, $Res Function(CameraErrorEvent) _then) = _$CameraErrorEventCopyWithImpl;
@useResult
$Res call({
 String code, String message
});




}
/// @nodoc
class _$CameraErrorEventCopyWithImpl<$Res>
    implements $CameraErrorEventCopyWith<$Res> {
  _$CameraErrorEventCopyWithImpl(this._self, this._then);

  final CameraErrorEvent _self;
  final $Res Function(CameraErrorEvent) _then;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,}) {
  return _then(CameraErrorEvent(
null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
