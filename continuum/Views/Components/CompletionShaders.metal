#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The completion moment, in two layers. `t` runs 0 → 1 over the effect.

// A shockwave out from the card's centre that bends whatever it passes over,
// with the colour channels pulled apart along the wavefront, and a twist at
// the centre that unwinds as it goes.
[[ stitchable ]] half4 completionRipple(float2 position, SwiftUI::Layer layer, float2 size, float t) {
    float2 origin = size * 0.5;
    float2 d = position - origin;
    float dist = length(d);
    float2 dir = dist > 0.001 ? d / dist : float2(0.0);

    float twist = 0.7 * pow(1.0 - t, 3.0) * exp(-dist / (0.16 * max(size.x, size.y)));
    float2 p = origin + float2(d.x * cos(twist) - d.y * sin(twist),
                               d.x * sin(twist) + d.y * cos(twist));

    float reach = length(size) * 0.75;
    float k = dist - t * reach;
    // Ringing behind the front, nothing ahead of it
    float wave = sin(k * 0.11) * exp(-abs(k) * 0.025) * step(k, 12.0);
    float offset = wave * 12.0 * (1.0 - t) * (1.0 - t);

    p -= dir * offset;
    float split = offset * 0.45;
    half4 base = layer.sample(p);
    half r = layer.sample(p - dir * split).r;
    half b = layer.sample(p + dir * split).b;
    return half4(r, base.g, b, base.a);
}

// Cosine rainbow, phase-shifted per channel
static float3 spectrum(float x) {
    return 0.5 + 0.5 * cos(6.2831853 * (x + float3(0.0, 0.33, 0.67)));
}

// An n-fold mirrored, domain-warped field: the bones of one mandala layer.
static float mandalaField(float r, float a, float n, float spin, float t, float amp, float phase) {
    float seg = 6.2831853 / n;
    float ka = abs(fmod(a + spin + 31.4159265, seg) - seg * 0.5);
    float2 q = float2(cos(ka), sin(ka)) * r * 4.0;
    for (int i = 1; i < 4; i++) {
        float fi = float(i);
        float2 w = q;
        q.x += amp / fi * sin(fi * w.y * 1.6 + t * 4.0 + fi + phase);
        q.y += amp / fi * cos(fi * w.x * 1.4 - t * 3.0 + fi * 1.3 + phase);
    }
    return sin(q.x * 1.3) * cos(q.y * 1.3);
}

// Two kaleidoscopic mandalas, 8-fold and 12-fold, turning against each other
// as fine neon filigree inside a gold ring that opens across the card.
// Premultiplied output for a .plusLighter overlay.
[[ stitchable ]] half4 completionBloom(float2 position, half4 color, float2 size, float t) {
    float2 uv = (position - size * 0.5) / max(size.x, size.y);
    float r = length(uv);
    float a = atan2(uv.y, uv.x);

    float f1 = mandalaField(r, a, 8.0, -t * 0.9, t, 0.45, 0.0);
    float f2 = mandalaField(r, a, 12.0, t * 0.6, t, 0.30, 2.0);
    float l1 = pow(0.5 + 0.5 * cos(f1 * 7.0 + r * 14.0 - t * 10.0), 22.0);
    float l2 = pow(0.5 + 0.5 * cos(f2 * 6.0 - r * 18.0 + t * 7.0), 28.0);
    float3 c1 = spectrum(f1 * 0.45 + r * 1.4 - t * 1.8);
    float3 c2 = spectrum(f2 * 0.45 + r * 1.4 - t * 1.8 + 0.5);
    float3 gold = float3(1.0, 0.8, 0.35);

    float R = 0.9 * (1.0 - pow(1.0 - t, 2.4));
    float disk = clamp((R - r) / 0.2, 0.0, 1.0);
    float rim = exp(-pow((r - R) * 15.0, 2.0));
    float glow = exp(-r * 6.0) * 0.15;
    float env = clamp(t / 0.1, 0.0, 1.0) * pow(1.0 - t, 1.4);

    float3 col = (c1 * l1 * 1.3 + c2 * l2 + c1 * 0.12) * disk + gold * (rim * 0.6 + glow * disk);
    col = clamp(col * env, 0.0, 1.0);
    // Additive: alpha only needs to cover the brightest channel
    return half4(half3(col), half(max(col.r, max(col.g, col.b))));
}
