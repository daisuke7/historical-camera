#include <metal_stdlib>
using namespace metal;

// Uniform layout: the 20 FilterParams fields in docs/02 §2 declaration order,
// then time / width / height / orientation — 24 floats total. Must match
// `FilterUniforms` in FilterRenderer.swift exactly (docs/05 §4.2).
struct Uniforms {
    float monochrome;
    float sepia;
    float saturation;
    float contrast;
    float brightness;
    float warmth;
    float fade;
    float grain;
    float grainSize;
    float vignette;
    float scratches;
    float dust;
    float jitter;
    float halation;
    float blur;
    float orthochromatic;
    float engraving;
    float hatchScale;
    float inkPainting;
    float paperTexture;
    float time;
    float width;
    float height;
    float orientation;
};

// ---------------------------------------------------------------------------
// Utilities — implement exactly as specified in docs/03 §3.2; the value
// ranges are coupled to downstream thresholds.
// ---------------------------------------------------------------------------

static inline float hash21(float2 p) {
    // Bound the argument to avoid float precision breakdown.
    p = fmod(p, float2(1024.0));
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// 2D value noise, range [0, 1].
static inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + float2(1.0, 0.0)), u.x),
        mix(hash21(i + float2(0.0, 1.0)), hash21(i + float2(1.0, 1.0)), u.x),
        u.y);
}

// 3-octave fbm, amplitudes 0.5/0.25/0.125 normalized by 0.875 -> [0, 1].
static inline float fbm3(float2 p) {
    return (0.5 * valueNoise(p)
          + 0.25 * valueNoise(p * 2.0)
          + 0.125 * valueNoise(p * 4.0)) / 0.875;
}

static inline float lumaOf(float3 c) {
    return dot(c, float3(0.299, 0.587, 0.114));
}

// Rotation in 90-degree steps around (0.5, 0.5).
static inline float2 rotQ(float2 p, float q) {
    p -= 0.5;
    if (q > 2.5) {
        p = float2(-p.y, p.x);
    } else if (q > 1.5) {
        p = -p;
    } else if (q > 0.5) {
        p = float2(p.y, -p.x);
    }
    return p + 0.5;
}

// 5-tap blur. Offset = amount * 3 texels; weights 0.4 center, 0.15 sides.
// Early-out single sample when amount <= 0.
static inline float3 sampleBlurred(
    texture2d<float, access::sample> tex, float2 uv, float amount, float2 res)
{
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    if (amount <= 0.0) {
        return tex.sample(smp, uv).rgb;
    }
    float2 o = float2(amount * 3.0) / res;
    return tex.sample(smp, uv).rgb * 0.4
        + (tex.sample(smp, uv + float2(o.x, 0.0)).rgb
         + tex.sample(smp, uv - float2(o.x, 0.0)).rgb
         + tex.sample(smp, uv + float2(0.0, o.y)).rgb
         + tex.sample(smp, uv - float2(0.0, o.y)).rgb) * 0.15;
}

// Sobel edge strength on 3x3 luma with 2-texel spacing (acts as a slight
// pre-blur against camera noise). Returns clamp(length((gx, gy)), 0, 1).
static float sobelLuma(
    texture2d<float, access::sample> tex, float2 uv, float2 res)
{
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float2 o = 2.0 / res;
    float l00 = lumaOf(tex.sample(smp, uv + float2(-o.x, -o.y)).rgb);
    float l10 = lumaOf(tex.sample(smp, uv + float2(0.0, -o.y)).rgb);
    float l20 = lumaOf(tex.sample(smp, uv + float2(o.x, -o.y)).rgb);
    float l01 = lumaOf(tex.sample(smp, uv + float2(-o.x, 0.0)).rgb);
    float l21 = lumaOf(tex.sample(smp, uv + float2(o.x, 0.0)).rgb);
    float l02 = lumaOf(tex.sample(smp, uv + float2(-o.x, o.y)).rgb);
    float l12 = lumaOf(tex.sample(smp, uv + float2(0.0, o.y)).rgb);
    float l22 = lumaOf(tex.sample(smp, uv + float2(o.x, o.y)).rgb);
    float gx = -l00 - 2.0 * l01 - l02 + l20 + 2.0 * l21 + l22;
    float gy = -l00 - 2.0 * l10 - l20 + l02 + 2.0 * l12 + l22;
    return clamp(length(float2(gx, gy)), 0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Still-photo pre-pass (docs/02 §4.1, 05 §3.4): rotates the sensor-oriented
// photo buffer upright (clockwise 90° x quarterTurns) and optionally mirrors
// the final image (front camera, to match the mirrored preview).
// ---------------------------------------------------------------------------
struct RotateUniforms {
    uint dstWidth;
    uint dstHeight;
    uint quarterTurns;
    uint mirror;
};

kernel void rotateQuarter(
    texture2d<float, access::read> src [[texture(0)]],
    texture2d<float, access::write> dst [[texture(1)]],
    constant RotateUniforms &r [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= r.dstWidth || gid.y >= r.dstHeight) {
        return;
    }
    uint srcW = src.get_width();
    uint srcH = src.get_height();
    // Mirror flips the FINAL (display-space) image horizontally.
    uint2 g = gid;
    if (r.mirror != 0u) {
        g.x = r.dstWidth - 1u - g.x;
    }
    uint2 s;
    switch (r.quarterTurns) {
        case 1u: s = uint2(g.y, srcH - 1u - g.x); break;
        case 2u: s = uint2(srcW - 1u - g.x, srcH - 1u - g.y); break;
        case 3u: s = uint2(srcW - 1u - g.y, g.x); break;
        default: s = g; break;
    }
    dst.write(src.read(s), gid);
}

// ---------------------------------------------------------------------------
// Era filter (docs/03 §3.3). Single pass; per-effect uniform branches are
// coherent across threads and skip work at the modern end of the slider.
// ---------------------------------------------------------------------------
kernel void eraFilter(
    texture2d<float, access::sample> src [[texture(0)]],
    texture2d<float, access::write> dst [[texture(1)]],
    constant Uniforms &u [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Bounds guard: dispatched with dispatchThreadgroups, which may overshoot
    // the texture size (docs/05 §4.2 — dispatchThreads is forbidden).
    if (gid.x >= uint(u.width) || gid.y >= uint(u.height)) {
        return;
    }
    constexpr sampler smp(filter::linear, address::clamp_to_edge);

    float2 res = float2(u.width, u.height);
    float2 uv = (float2(gid) + 0.5) / res;
    // Direction-dependent effects draw in display orientation (docs/03 §3.1).
    float2 euv = rotQ(uv, u.orientation);

    // 1. jitter: smooth low-frequency wander + slight zoom to hide edges.
    float tj = u.time * 12.0;
    float2 j0 = float2(hash21(float2(floor(tj), 1.0)),
                       hash21(float2(floor(tj), 2.0)));
    float2 j1 = float2(hash21(float2(floor(tj) + 1.0, 1.0)),
                       hash21(float2(floor(tj) + 1.0, 2.0)));
    float2 wander = mix(j0, j1, smoothstep(0.0, 1.0, fract(tj))) - 0.5;
    uv = (uv - 0.5) * (1.0 - 0.012 * u.jitter) + 0.5;
    uv += wander * 0.006 * u.jitter;

    // Sampling coordinate; texMatrix is the identity on iOS (docs/03 §3.1).
    float2 suv = uv;

    // 2. blur: overall softness of an old lens.
    float3 c = sampleBlurred(src, suv, u.blur, res);

    // 3. tone (fixed order: brightness -> contrast -> saturation -> warmth
    //    -> fade).
    c += u.brightness;
    c = (c - 0.5) * u.contrast + 0.5;
    c = mix(float3(lumaOf(c)), c, u.saturation);
    c += float3(0.06, 0.015, -0.06) * u.warmth;
    c = mix(c, c * 0.85 + 0.13, u.fade);

    // 4. monochrome (with orthochromatic plate response) / sepia.
    float yPan = lumaOf(c);
    float yOrtho = dot(c, float3(0.10, 0.50, 0.40));
    float y = mix(yPan, yOrtho, u.orthochromatic);
    c = mix(c, float3(y), u.monochrome);
    c = mix(c, y * float3(1.10, 0.90, 0.65) + float3(0.06, 0.03, 0.0),
            u.sepia * 0.85);

    // 5. halation: highlight glow from an 8-point ring average.
    if (u.halation > 0.0) {
        float2 rad = float2(12.0 + 8.0 * u.halation) / res;
        float3 glow = float3(0.0);
        for (int i = 0; i < 8; i++) {
            float a = float(i) * 0.7854; // 2*pi / 8
            glow += src.sample(smp, suv + float2(cos(a), sin(a)) * rad).rgb;
        }
        float bright = smoothstep(0.7, 1.0, lumaOf(glow / 8.0));
        c += bright * u.halation * float3(0.25, 0.18, 0.10);
    }

    // 6. engraving: cross-hatch whose line width follows tone, with a
    //    hand-carved wobble. Analytic AA — fwidth is unavailable in compute.
    if (u.engraving > 0.0) {
        float tone = clamp(lumaOf(c), 0.0, 1.0);
        float k = 90.0 * u.hatchScale;
        float wob = (fbm3(euv * 24.0) - 0.5) * 2.5;
        float d1 = (euv.x + euv.y) * k * 3.1416 + wob;
        float d2 = (euv.x - euv.y) * k * 3.1416 + wob * 1.3;
        float aa = k * 3.1416 * (1.0 / res.x + 1.0 / res.y) * 0.5 + 0.06;
        float l1 = smoothstep(tone - aa, tone + aa, 0.5 + 0.5 * sin(d1));
        float l2 = smoothstep(tone * 1.6 - aa, tone * 1.6 + aa,
                              0.5 + 0.5 * sin(d2));
        float inkAmt = clamp(l1 + l2 * 0.8, 0.0, 1.0);
        float3 inkCol = float3(0.18, 0.12, 0.08);
        float3 paperC = float3(0.93, 0.88, 0.78);
        c = mix(c, mix(paperC, inkCol, inkAmt * 0.9), u.engraving);
    }

    // 7. ink painting: Sobel ink lines + soft posterize + ink bleed.
    if (u.inkPainting > 0.0) {
        float edge = sobelLuma(src, suv, res);
        float t0 = lumaOf(c);
        float n = 4.0;
        float tq = (floor(t0 * n) + smoothstep(0.35, 0.65, fract(t0 * n))) / n;
        float bleed = fbm3(uv * 60.0) * 0.15;
        float3 paperC = float3(0.90, 0.85, 0.72);
        float3 wash = mix(float3(0.25, 0.22, 0.18), paperC, tq * 0.85 + 0.15);
        float3 inked = mix(wash, float3(0.10, 0.08, 0.06),
                           smoothstep(0.25 - bleed, 0.6, edge));
        c = mix(c, inked, u.inkPainting);
    }

    // 8. grain: 24 Hz reseeded (no 1-second loop), strongest in midtones.
    float gseed = floor(u.time * 24.0);
    float g = hash21(floor(uv * res / u.grainSize)
                     + float2(gseed * 13.1, gseed * 7.7)) - 0.5;
    float lum = lumaOf(c);
    float lw = 4.0 * lum * (1.0 - lum);
    c += g * u.grain * 0.25 * mix(0.5, 1.0, lw);

    // 9. scratches: generational vertical scratches that persist for ~2 s and
    //    wander slowly; light and dark variants, probabilistic appearance.
    if (u.scratches > 0.0) {
        for (int i = 0; i < 3; i++) {
            float seed = float(i) * 7.31;
            float seg = floor(u.time * 0.5) + seed;
            float life = step(0.55, hash21(float2(seg, 3.0)));
            float sx = hash21(float2(seg, 1.0))
                + (valueNoise(float2(u.time * 1.7, seed)) - 0.5) * 0.02;
            float line = (1.0 - smoothstep(0.0, 0.0015, fabs(euv.x - sx)))
                * life;
            float toneS = (hash21(float2(seg, 2.0)) > 0.5) ? 0.4 : -0.35;
            c += line * u.scratches * toneS;
        }
    }

    // 10. dust: static dark stains + per-frame light specks.
    if (u.dust > 0.0) {
        float aspect = res.x / res.y;
        float stain = smoothstep(0.80, 0.90,
                                 valueNoise(uv * float2(aspect, 1.0) * 24.0));
        float fseed = floor(u.time * 24.0);
        float flick = smoothstep(1.0 - u.dust * 0.05, 1.0 - u.dust * 0.02,
                                 valueNoise(uv * 60.0
                                     + float2(fseed * 13.1, fseed * 7.7)));
        c = mix(c, c * 0.55, stain * u.dust * 0.6);
        c = mix(c, float3(0.9), flick * u.dust * 0.8);
    }

    // 11. paper texture: low-frequency mottle + high-frequency fibers,
    //     resolution-independent.
    if (u.paperTexture > 0.0) {
        float aspect = res.x / res.y;
        float2 puv = uv * float2(aspect, 1.0);
        float ptex = 0.75 * fbm3(puv * 7.0) + 0.25 * fbm3(puv * 90.0);
        c *= mix(1.0, 0.80 + 0.20 * ptex, u.paperTexture);
    }

    // 12. projector flicker (rides on jitter).
    c *= 1.0 + (hash21(float2(floor(u.time * 24.0), 5.0)) - 0.5)
        * 0.06 * u.jitter;

    // 13. vignette.
    float r = distance(uv, float2(0.5)) * 1.414;
    c *= 1.0 - u.vignette * smoothstep(0.45, 1.0, r);

    dst.write(float4(clamp(c, 0.0, 1.0), 1.0), gid);
}
