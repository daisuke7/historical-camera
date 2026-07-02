// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'filter_params.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FilterParams {

/// 0 = full color, 1 = fully monochrome.
 double get monochrome;/// Sepia toning strength.
 double get sepia;/// Saturation scale 0..2 (1 = unchanged).
 double get saturation;/// Contrast scale 0.5..1.5 (1 = unchanged).
 double get contrast;/// Brightness offset -0.3..0.3 (0 = unchanged).
 double get brightness;/// Color temperature shift -1 (blue) .. 1 (amber).
 double get warmth;/// Lifted blacks / sunk whites of a faded print.
 double get fade;/// Film grain intensity.
 double get grain;/// Grain size in pixel units, 1..4.
 double get grainSize;/// Peripheral darkening.
 double get vignette;/// Amount of vertical film scratches.
 double get scratches;/// Amount of dust specks and stains.
 double get dust;/// Frame wander + projector flicker of old footage.
 double get jitter;/// Highlight bloom.
 double get halation;/// Overall softness of an old lens.
 double get blur;/// Orthochromatic plate response 0..1 (red sinks dark, sky blows white).
 double get orthochromatic;/// Engraving-mode blend 0..1 (era 1500-1840).
 double get engraving;/// Engraving line density factor 0.5..1.0
/// (1 = fine copperplate lines, 0.5 = coarse woodblock lines).
 double get hatchScale;/// Ink-painting / picture-scroll blend 0..1 (era 1000-1500).
 double get inkPainting;/// Paper texture blend.
 double get paperTexture;
/// Create a copy of FilterParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilterParamsCopyWith<FilterParams> get copyWith => _$FilterParamsCopyWithImpl<FilterParams>(this as FilterParams, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FilterParams&&(identical(other.monochrome, monochrome) || other.monochrome == monochrome)&&(identical(other.sepia, sepia) || other.sepia == sepia)&&(identical(other.saturation, saturation) || other.saturation == saturation)&&(identical(other.contrast, contrast) || other.contrast == contrast)&&(identical(other.brightness, brightness) || other.brightness == brightness)&&(identical(other.warmth, warmth) || other.warmth == warmth)&&(identical(other.fade, fade) || other.fade == fade)&&(identical(other.grain, grain) || other.grain == grain)&&(identical(other.grainSize, grainSize) || other.grainSize == grainSize)&&(identical(other.vignette, vignette) || other.vignette == vignette)&&(identical(other.scratches, scratches) || other.scratches == scratches)&&(identical(other.dust, dust) || other.dust == dust)&&(identical(other.jitter, jitter) || other.jitter == jitter)&&(identical(other.halation, halation) || other.halation == halation)&&(identical(other.blur, blur) || other.blur == blur)&&(identical(other.orthochromatic, orthochromatic) || other.orthochromatic == orthochromatic)&&(identical(other.engraving, engraving) || other.engraving == engraving)&&(identical(other.hatchScale, hatchScale) || other.hatchScale == hatchScale)&&(identical(other.inkPainting, inkPainting) || other.inkPainting == inkPainting)&&(identical(other.paperTexture, paperTexture) || other.paperTexture == paperTexture));
}


@override
int get hashCode => Object.hashAll([runtimeType,monochrome,sepia,saturation,contrast,brightness,warmth,fade,grain,grainSize,vignette,scratches,dust,jitter,halation,blur,orthochromatic,engraving,hatchScale,inkPainting,paperTexture]);

@override
String toString() {
  return 'FilterParams(monochrome: $monochrome, sepia: $sepia, saturation: $saturation, contrast: $contrast, brightness: $brightness, warmth: $warmth, fade: $fade, grain: $grain, grainSize: $grainSize, vignette: $vignette, scratches: $scratches, dust: $dust, jitter: $jitter, halation: $halation, blur: $blur, orthochromatic: $orthochromatic, engraving: $engraving, hatchScale: $hatchScale, inkPainting: $inkPainting, paperTexture: $paperTexture)';
}


}

/// @nodoc
abstract mixin class $FilterParamsCopyWith<$Res>  {
  factory $FilterParamsCopyWith(FilterParams value, $Res Function(FilterParams) _then) = _$FilterParamsCopyWithImpl;
@useResult
$Res call({
 double monochrome, double sepia, double saturation, double contrast, double brightness, double warmth, double fade, double grain, double grainSize, double vignette, double scratches, double dust, double jitter, double halation, double blur, double orthochromatic, double engraving, double hatchScale, double inkPainting, double paperTexture
});




}
/// @nodoc
class _$FilterParamsCopyWithImpl<$Res>
    implements $FilterParamsCopyWith<$Res> {
  _$FilterParamsCopyWithImpl(this._self, this._then);

  final FilterParams _self;
  final $Res Function(FilterParams) _then;

/// Create a copy of FilterParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? monochrome = null,Object? sepia = null,Object? saturation = null,Object? contrast = null,Object? brightness = null,Object? warmth = null,Object? fade = null,Object? grain = null,Object? grainSize = null,Object? vignette = null,Object? scratches = null,Object? dust = null,Object? jitter = null,Object? halation = null,Object? blur = null,Object? orthochromatic = null,Object? engraving = null,Object? hatchScale = null,Object? inkPainting = null,Object? paperTexture = null,}) {
  return _then(_self.copyWith(
monochrome: null == monochrome ? _self.monochrome : monochrome // ignore: cast_nullable_to_non_nullable
as double,sepia: null == sepia ? _self.sepia : sepia // ignore: cast_nullable_to_non_nullable
as double,saturation: null == saturation ? _self.saturation : saturation // ignore: cast_nullable_to_non_nullable
as double,contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as double,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as double,warmth: null == warmth ? _self.warmth : warmth // ignore: cast_nullable_to_non_nullable
as double,fade: null == fade ? _self.fade : fade // ignore: cast_nullable_to_non_nullable
as double,grain: null == grain ? _self.grain : grain // ignore: cast_nullable_to_non_nullable
as double,grainSize: null == grainSize ? _self.grainSize : grainSize // ignore: cast_nullable_to_non_nullable
as double,vignette: null == vignette ? _self.vignette : vignette // ignore: cast_nullable_to_non_nullable
as double,scratches: null == scratches ? _self.scratches : scratches // ignore: cast_nullable_to_non_nullable
as double,dust: null == dust ? _self.dust : dust // ignore: cast_nullable_to_non_nullable
as double,jitter: null == jitter ? _self.jitter : jitter // ignore: cast_nullable_to_non_nullable
as double,halation: null == halation ? _self.halation : halation // ignore: cast_nullable_to_non_nullable
as double,blur: null == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as double,orthochromatic: null == orthochromatic ? _self.orthochromatic : orthochromatic // ignore: cast_nullable_to_non_nullable
as double,engraving: null == engraving ? _self.engraving : engraving // ignore: cast_nullable_to_non_nullable
as double,hatchScale: null == hatchScale ? _self.hatchScale : hatchScale // ignore: cast_nullable_to_non_nullable
as double,inkPainting: null == inkPainting ? _self.inkPainting : inkPainting // ignore: cast_nullable_to_non_nullable
as double,paperTexture: null == paperTexture ? _self.paperTexture : paperTexture // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [FilterParams].
extension FilterParamsPatterns on FilterParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FilterParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FilterParams() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FilterParams value)  $default,){
final _that = this;
switch (_that) {
case _FilterParams():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FilterParams value)?  $default,){
final _that = this;
switch (_that) {
case _FilterParams() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double monochrome,  double sepia,  double saturation,  double contrast,  double brightness,  double warmth,  double fade,  double grain,  double grainSize,  double vignette,  double scratches,  double dust,  double jitter,  double halation,  double blur,  double orthochromatic,  double engraving,  double hatchScale,  double inkPainting,  double paperTexture)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FilterParams() when $default != null:
return $default(_that.monochrome,_that.sepia,_that.saturation,_that.contrast,_that.brightness,_that.warmth,_that.fade,_that.grain,_that.grainSize,_that.vignette,_that.scratches,_that.dust,_that.jitter,_that.halation,_that.blur,_that.orthochromatic,_that.engraving,_that.hatchScale,_that.inkPainting,_that.paperTexture);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double monochrome,  double sepia,  double saturation,  double contrast,  double brightness,  double warmth,  double fade,  double grain,  double grainSize,  double vignette,  double scratches,  double dust,  double jitter,  double halation,  double blur,  double orthochromatic,  double engraving,  double hatchScale,  double inkPainting,  double paperTexture)  $default,) {final _that = this;
switch (_that) {
case _FilterParams():
return $default(_that.monochrome,_that.sepia,_that.saturation,_that.contrast,_that.brightness,_that.warmth,_that.fade,_that.grain,_that.grainSize,_that.vignette,_that.scratches,_that.dust,_that.jitter,_that.halation,_that.blur,_that.orthochromatic,_that.engraving,_that.hatchScale,_that.inkPainting,_that.paperTexture);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double monochrome,  double sepia,  double saturation,  double contrast,  double brightness,  double warmth,  double fade,  double grain,  double grainSize,  double vignette,  double scratches,  double dust,  double jitter,  double halation,  double blur,  double orthochromatic,  double engraving,  double hatchScale,  double inkPainting,  double paperTexture)?  $default,) {final _that = this;
switch (_that) {
case _FilterParams() when $default != null:
return $default(_that.monochrome,_that.sepia,_that.saturation,_that.contrast,_that.brightness,_that.warmth,_that.fade,_that.grain,_that.grainSize,_that.vignette,_that.scratches,_that.dust,_that.jitter,_that.halation,_that.blur,_that.orthochromatic,_that.engraving,_that.hatchScale,_that.inkPainting,_that.paperTexture);case _:
  return null;

}
}

}

/// @nodoc


class _FilterParams extends FilterParams {
  const _FilterParams({required this.monochrome, required this.sepia, required this.saturation, required this.contrast, required this.brightness, required this.warmth, required this.fade, required this.grain, required this.grainSize, required this.vignette, required this.scratches, required this.dust, required this.jitter, required this.halation, required this.blur, required this.orthochromatic, required this.engraving, required this.hatchScale, required this.inkPainting, required this.paperTexture}): super._();
  

/// 0 = full color, 1 = fully monochrome.
@override final  double monochrome;
/// Sepia toning strength.
@override final  double sepia;
/// Saturation scale 0..2 (1 = unchanged).
@override final  double saturation;
/// Contrast scale 0.5..1.5 (1 = unchanged).
@override final  double contrast;
/// Brightness offset -0.3..0.3 (0 = unchanged).
@override final  double brightness;
/// Color temperature shift -1 (blue) .. 1 (amber).
@override final  double warmth;
/// Lifted blacks / sunk whites of a faded print.
@override final  double fade;
/// Film grain intensity.
@override final  double grain;
/// Grain size in pixel units, 1..4.
@override final  double grainSize;
/// Peripheral darkening.
@override final  double vignette;
/// Amount of vertical film scratches.
@override final  double scratches;
/// Amount of dust specks and stains.
@override final  double dust;
/// Frame wander + projector flicker of old footage.
@override final  double jitter;
/// Highlight bloom.
@override final  double halation;
/// Overall softness of an old lens.
@override final  double blur;
/// Orthochromatic plate response 0..1 (red sinks dark, sky blows white).
@override final  double orthochromatic;
/// Engraving-mode blend 0..1 (era 1500-1840).
@override final  double engraving;
/// Engraving line density factor 0.5..1.0
/// (1 = fine copperplate lines, 0.5 = coarse woodblock lines).
@override final  double hatchScale;
/// Ink-painting / picture-scroll blend 0..1 (era 1000-1500).
@override final  double inkPainting;
/// Paper texture blend.
@override final  double paperTexture;

/// Create a copy of FilterParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FilterParamsCopyWith<_FilterParams> get copyWith => __$FilterParamsCopyWithImpl<_FilterParams>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FilterParams&&(identical(other.monochrome, monochrome) || other.monochrome == monochrome)&&(identical(other.sepia, sepia) || other.sepia == sepia)&&(identical(other.saturation, saturation) || other.saturation == saturation)&&(identical(other.contrast, contrast) || other.contrast == contrast)&&(identical(other.brightness, brightness) || other.brightness == brightness)&&(identical(other.warmth, warmth) || other.warmth == warmth)&&(identical(other.fade, fade) || other.fade == fade)&&(identical(other.grain, grain) || other.grain == grain)&&(identical(other.grainSize, grainSize) || other.grainSize == grainSize)&&(identical(other.vignette, vignette) || other.vignette == vignette)&&(identical(other.scratches, scratches) || other.scratches == scratches)&&(identical(other.dust, dust) || other.dust == dust)&&(identical(other.jitter, jitter) || other.jitter == jitter)&&(identical(other.halation, halation) || other.halation == halation)&&(identical(other.blur, blur) || other.blur == blur)&&(identical(other.orthochromatic, orthochromatic) || other.orthochromatic == orthochromatic)&&(identical(other.engraving, engraving) || other.engraving == engraving)&&(identical(other.hatchScale, hatchScale) || other.hatchScale == hatchScale)&&(identical(other.inkPainting, inkPainting) || other.inkPainting == inkPainting)&&(identical(other.paperTexture, paperTexture) || other.paperTexture == paperTexture));
}


@override
int get hashCode => Object.hashAll([runtimeType,monochrome,sepia,saturation,contrast,brightness,warmth,fade,grain,grainSize,vignette,scratches,dust,jitter,halation,blur,orthochromatic,engraving,hatchScale,inkPainting,paperTexture]);

@override
String toString() {
  return 'FilterParams(monochrome: $monochrome, sepia: $sepia, saturation: $saturation, contrast: $contrast, brightness: $brightness, warmth: $warmth, fade: $fade, grain: $grain, grainSize: $grainSize, vignette: $vignette, scratches: $scratches, dust: $dust, jitter: $jitter, halation: $halation, blur: $blur, orthochromatic: $orthochromatic, engraving: $engraving, hatchScale: $hatchScale, inkPainting: $inkPainting, paperTexture: $paperTexture)';
}


}

/// @nodoc
abstract mixin class _$FilterParamsCopyWith<$Res> implements $FilterParamsCopyWith<$Res> {
  factory _$FilterParamsCopyWith(_FilterParams value, $Res Function(_FilterParams) _then) = __$FilterParamsCopyWithImpl;
@override @useResult
$Res call({
 double monochrome, double sepia, double saturation, double contrast, double brightness, double warmth, double fade, double grain, double grainSize, double vignette, double scratches, double dust, double jitter, double halation, double blur, double orthochromatic, double engraving, double hatchScale, double inkPainting, double paperTexture
});




}
/// @nodoc
class __$FilterParamsCopyWithImpl<$Res>
    implements _$FilterParamsCopyWith<$Res> {
  __$FilterParamsCopyWithImpl(this._self, this._then);

  final _FilterParams _self;
  final $Res Function(_FilterParams) _then;

/// Create a copy of FilterParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? monochrome = null,Object? sepia = null,Object? saturation = null,Object? contrast = null,Object? brightness = null,Object? warmth = null,Object? fade = null,Object? grain = null,Object? grainSize = null,Object? vignette = null,Object? scratches = null,Object? dust = null,Object? jitter = null,Object? halation = null,Object? blur = null,Object? orthochromatic = null,Object? engraving = null,Object? hatchScale = null,Object? inkPainting = null,Object? paperTexture = null,}) {
  return _then(_FilterParams(
monochrome: null == monochrome ? _self.monochrome : monochrome // ignore: cast_nullable_to_non_nullable
as double,sepia: null == sepia ? _self.sepia : sepia // ignore: cast_nullable_to_non_nullable
as double,saturation: null == saturation ? _self.saturation : saturation // ignore: cast_nullable_to_non_nullable
as double,contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as double,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as double,warmth: null == warmth ? _self.warmth : warmth // ignore: cast_nullable_to_non_nullable
as double,fade: null == fade ? _self.fade : fade // ignore: cast_nullable_to_non_nullable
as double,grain: null == grain ? _self.grain : grain // ignore: cast_nullable_to_non_nullable
as double,grainSize: null == grainSize ? _self.grainSize : grainSize // ignore: cast_nullable_to_non_nullable
as double,vignette: null == vignette ? _self.vignette : vignette // ignore: cast_nullable_to_non_nullable
as double,scratches: null == scratches ? _self.scratches : scratches // ignore: cast_nullable_to_non_nullable
as double,dust: null == dust ? _self.dust : dust // ignore: cast_nullable_to_non_nullable
as double,jitter: null == jitter ? _self.jitter : jitter // ignore: cast_nullable_to_non_nullable
as double,halation: null == halation ? _self.halation : halation // ignore: cast_nullable_to_non_nullable
as double,blur: null == blur ? _self.blur : blur // ignore: cast_nullable_to_non_nullable
as double,orthochromatic: null == orthochromatic ? _self.orthochromatic : orthochromatic // ignore: cast_nullable_to_non_nullable
as double,engraving: null == engraving ? _self.engraving : engraving // ignore: cast_nullable_to_non_nullable
as double,hatchScale: null == hatchScale ? _self.hatchScale : hatchScale // ignore: cast_nullable_to_non_nullable
as double,inkPainting: null == inkPainting ? _self.inkPainting : inkPainting // ignore: cast_nullable_to_non_nullable
as double,paperTexture: null == paperTexture ? _self.paperTexture : paperTexture // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
