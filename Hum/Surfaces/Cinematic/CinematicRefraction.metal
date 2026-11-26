#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// A slowly travelling refraction front. Artwork moves on the GPU; typography stays crisp.
[[ stitchable ]] half4 humRefraction(float2 position, SwiftUI::Layer layer, float2 size, float time) {
    float2 uv = position / max(size, float2(1));
    float phase = time * 0.38;
    float front = 0.5 + 0.60 * sin(phase * 0.53);
    float curve = uv.x - front + 0.13 * sin(uv.y * 5.0 + phase);
    float envelope = exp(-curve * curve * 45.0);
    float wave = sin(curve * 14.0 + uv.y * 3.0 - phase);
    float unit = min(size.y, size.x * 0.8);
    float2 displacement = float2(wave, 0.45 * cos(uv.y * 6.0 + phase)) * envelope * unit * 0.028;
    float2 samplePosition = clamp(position + displacement, float2(0.5), size - 0.5);
    half4 color = layer.sample(samplePosition);
    float rim = exp(-pow((curve + 0.035) * 25.0, 2.0));
    float shadow = envelope * 0.13;
    color.rgb *= half(1.0 - shadow);
    // Gentle neutral glints preserve album color instead of washing out the whole image.
    color.rgb += half3(rim * 0.09) * color.a;
    return color;
}
