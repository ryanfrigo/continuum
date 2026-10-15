#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The completion moment, in two layers. `t` runs 0 → 1 over the effect.

// A shockwave out from the card's centre that bends whatever it passes over,
// with the colour channels pulled apart along the wavefront.
[[ stitchable ]] half4 completionRipple(float2 position, SwiftUI::Layer layer, float2 size, float t) {
    float2 origin = size * 0.5;
    float2 d = position - origin;
    float dist = length(d);
    float2 dir = dist > 0.001 ? d / dist : float2(0.0);

    float reach = length(size) * 0.75;
    float front = t * reach;
    float k = dist - front;
    // Ringing behind the front, nothing ahead of it
    float wave = sin(k * 0.11) * exp(-abs(k) * 0.025) * step(k, 12.0);
    float amp = 12.0 * (1.0 - t) * (1.0 - t);
    float offset = wave * amp;

    float2 p = position - dir * offset;
    float split = offset * 0.45;
    half4 base = layer.sample(p);
    half r = layer.sample(p - dir * split).r;
    half b = layer.sample(p + dir * split).b;
    return half4(r, base.g, b, base.a);
}

// Kaleidoscoped Kali-set fractal riding the same wavefront: an iridescent,
// gold-leaning bloom that dissolves as it travels. Premultiplied output for
// a .plusLighter overlay.
[[ stitchable ]] half4 completionBloom(float2 position, half4 color, float2 size, float t) {
    float scale = max(size.x, size.y);
    float2 uv = (position - size * 0.5) / scale;
    float r = length(uv);
    float a = atan2(uv.y, uv.x);

    // Six-fold mirror, turning as it grows
    float seg = 6.2831853 / 6.0;
    float ka = abs(fmod(a + t * 1.2 + 31.4159265, seg) - seg * 0.5);
    float2 z = float2(cos(ka), sin(ka)) * r * (1.6 + t * 1.2);

    float v = 0.0;
    for (int i = 0; i < 5; i++) {
        z = abs(z) / max(dot(z, z), 0.02) - float2(0.78, 0.55);
        v += exp(-length(z) * 1.4);
    }
    v = min(v, 2.0);

    float front = t * 0.78;
    float ring = exp(-pow((r - front) * 14.0, 2.0));
    float wake = smoothstep(front, front - 0.25, r) * smoothstep(-0.05, 0.2, r) * 0.5;
    float fade = (1.0 - t) * smoothstep(0.0, 0.08, t);
    float m = (ring * 1.2 + wake * 0.45) * fade;

    float3 iridescent = 0.5 + 0.5 * cos(6.2831853 * (float3(0.0, 0.33, 0.67) + v * 0.45 + r * 1.6 - t * 1.2));
    float3 gold = float3(1.0, 0.78, 0.28);
    float3 col = mix(gold, iridescent, 0.7) * (0.45 + v * 0.45);

    float alpha = clamp(m * (0.25 + v * 0.45), 0.0, 0.8);
    return half4(half3(col * alpha), half(alpha));
}
