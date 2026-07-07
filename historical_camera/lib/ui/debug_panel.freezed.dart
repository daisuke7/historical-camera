// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'debug_panel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DebugPanelState {

/// Whether the panel overlay is on screen.
 bool get visible;/// Manual mode: panel sliders drive the filter instead of the era year.
/// Survives closing the panel (the 手動 badge marks it).
 bool get manual;/// Values driven by the sliders while [manual] is true.
 FilterParams get manualParams;/// Explicit resolution selection (docs/04 §8.2 verification toggle).
 String get resolutionPreset;/// Latest `debugStats` reading; null until the first event arrives.
 double? get gpuMs;
/// Create a copy of DebugPanelState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DebugPanelStateCopyWith<DebugPanelState> get copyWith => _$DebugPanelStateCopyWithImpl<DebugPanelState>(this as DebugPanelState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DebugPanelState&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.manual, manual) || other.manual == manual)&&(identical(other.manualParams, manualParams) || other.manualParams == manualParams)&&(identical(other.resolutionPreset, resolutionPreset) || other.resolutionPreset == resolutionPreset)&&(identical(other.gpuMs, gpuMs) || other.gpuMs == gpuMs));
}


@override
int get hashCode => Object.hash(runtimeType,visible,manual,manualParams,resolutionPreset,gpuMs);

@override
String toString() {
  return 'DebugPanelState(visible: $visible, manual: $manual, manualParams: $manualParams, resolutionPreset: $resolutionPreset, gpuMs: $gpuMs)';
}


}

/// @nodoc
abstract mixin class $DebugPanelStateCopyWith<$Res>  {
  factory $DebugPanelStateCopyWith(DebugPanelState value, $Res Function(DebugPanelState) _then) = _$DebugPanelStateCopyWithImpl;
@useResult
$Res call({
 bool visible, bool manual, FilterParams manualParams, String resolutionPreset, double? gpuMs
});


$FilterParamsCopyWith<$Res> get manualParams;

}
/// @nodoc
class _$DebugPanelStateCopyWithImpl<$Res>
    implements $DebugPanelStateCopyWith<$Res> {
  _$DebugPanelStateCopyWithImpl(this._self, this._then);

  final DebugPanelState _self;
  final $Res Function(DebugPanelState) _then;

/// Create a copy of DebugPanelState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? visible = null,Object? manual = null,Object? manualParams = null,Object? resolutionPreset = null,Object? gpuMs = freezed,}) {
  return _then(_self.copyWith(
visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,manual: null == manual ? _self.manual : manual // ignore: cast_nullable_to_non_nullable
as bool,manualParams: null == manualParams ? _self.manualParams : manualParams // ignore: cast_nullable_to_non_nullable
as FilterParams,resolutionPreset: null == resolutionPreset ? _self.resolutionPreset : resolutionPreset // ignore: cast_nullable_to_non_nullable
as String,gpuMs: freezed == gpuMs ? _self.gpuMs : gpuMs // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of DebugPanelState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FilterParamsCopyWith<$Res> get manualParams {
  
  return $FilterParamsCopyWith<$Res>(_self.manualParams, (value) {
    return _then(_self.copyWith(manualParams: value));
  });
}
}


/// Adds pattern-matching-related methods to [DebugPanelState].
extension DebugPanelStatePatterns on DebugPanelState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DebugPanelState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DebugPanelState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DebugPanelState value)  $default,){
final _that = this;
switch (_that) {
case _DebugPanelState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DebugPanelState value)?  $default,){
final _that = this;
switch (_that) {
case _DebugPanelState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool visible,  bool manual,  FilterParams manualParams,  String resolutionPreset,  double? gpuMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DebugPanelState() when $default != null:
return $default(_that.visible,_that.manual,_that.manualParams,_that.resolutionPreset,_that.gpuMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool visible,  bool manual,  FilterParams manualParams,  String resolutionPreset,  double? gpuMs)  $default,) {final _that = this;
switch (_that) {
case _DebugPanelState():
return $default(_that.visible,_that.manual,_that.manualParams,_that.resolutionPreset,_that.gpuMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool visible,  bool manual,  FilterParams manualParams,  String resolutionPreset,  double? gpuMs)?  $default,) {final _that = this;
switch (_that) {
case _DebugPanelState() when $default != null:
return $default(_that.visible,_that.manual,_that.manualParams,_that.resolutionPreset,_that.gpuMs);case _:
  return null;

}
}

}

/// @nodoc


class _DebugPanelState implements DebugPanelState {
  const _DebugPanelState({required this.visible, required this.manual, required this.manualParams, required this.resolutionPreset, this.gpuMs});
  

/// Whether the panel overlay is on screen.
@override final  bool visible;
/// Manual mode: panel sliders drive the filter instead of the era year.
/// Survives closing the panel (the 手動 badge marks it).
@override final  bool manual;
/// Values driven by the sliders while [manual] is true.
@override final  FilterParams manualParams;
/// Explicit resolution selection (docs/04 §8.2 verification toggle).
@override final  String resolutionPreset;
/// Latest `debugStats` reading; null until the first event arrives.
@override final  double? gpuMs;

/// Create a copy of DebugPanelState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DebugPanelStateCopyWith<_DebugPanelState> get copyWith => __$DebugPanelStateCopyWithImpl<_DebugPanelState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DebugPanelState&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.manual, manual) || other.manual == manual)&&(identical(other.manualParams, manualParams) || other.manualParams == manualParams)&&(identical(other.resolutionPreset, resolutionPreset) || other.resolutionPreset == resolutionPreset)&&(identical(other.gpuMs, gpuMs) || other.gpuMs == gpuMs));
}


@override
int get hashCode => Object.hash(runtimeType,visible,manual,manualParams,resolutionPreset,gpuMs);

@override
String toString() {
  return 'DebugPanelState(visible: $visible, manual: $manual, manualParams: $manualParams, resolutionPreset: $resolutionPreset, gpuMs: $gpuMs)';
}


}

/// @nodoc
abstract mixin class _$DebugPanelStateCopyWith<$Res> implements $DebugPanelStateCopyWith<$Res> {
  factory _$DebugPanelStateCopyWith(_DebugPanelState value, $Res Function(_DebugPanelState) _then) = __$DebugPanelStateCopyWithImpl;
@override @useResult
$Res call({
 bool visible, bool manual, FilterParams manualParams, String resolutionPreset, double? gpuMs
});


@override $FilterParamsCopyWith<$Res> get manualParams;

}
/// @nodoc
class __$DebugPanelStateCopyWithImpl<$Res>
    implements _$DebugPanelStateCopyWith<$Res> {
  __$DebugPanelStateCopyWithImpl(this._self, this._then);

  final _DebugPanelState _self;
  final $Res Function(_DebugPanelState) _then;

/// Create a copy of DebugPanelState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? visible = null,Object? manual = null,Object? manualParams = null,Object? resolutionPreset = null,Object? gpuMs = freezed,}) {
  return _then(_DebugPanelState(
visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,manual: null == manual ? _self.manual : manual // ignore: cast_nullable_to_non_nullable
as bool,manualParams: null == manualParams ? _self.manualParams : manualParams // ignore: cast_nullable_to_non_nullable
as FilterParams,resolutionPreset: null == resolutionPreset ? _self.resolutionPreset : resolutionPreset // ignore: cast_nullable_to_non_nullable
as String,gpuMs: freezed == gpuMs ? _self.gpuMs : gpuMs // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of DebugPanelState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FilterParamsCopyWith<$Res> get manualParams {
  
  return $FilterParamsCopyWith<$Res>(_self.manualParams, (value) {
    return _then(_self.copyWith(manualParams: value));
  });
}
}

// dart format on
