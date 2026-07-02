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

// Era filter kernel. Task T5 ships this as a pass-through; the full
// algorithm from docs/03 §3 replaces the body in task T6.
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
    float2 uv = (float2(gid) + 0.5) / float2(u.width, u.height);
    float4 c = src.sample(smp, uv);
    dst.write(float4(c.rgb, 1.0), gid);
}
