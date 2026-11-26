#include <metal_stdlib>
using namespace metal;

// Signed distance to a rectangle whose top and bottom corners can have different radii.
static float edgeBox(float2 p, float2 origin, float2 size, float topRadius, float bottomRadius) {
    float2 halfSize = max(size * 0.5, float2(0.001));
    float2 local = p - origin - halfSize;
    float radius = min(local.y < 0 ? topRadius : bottomRadius, min(halfSize.x, halfSize.y));
    float2 q = abs(local) - halfSize + radius;
    return length(max(q, float2(0))) + min(max(q.x, q.y), 0.0) - radius;
}

// Analytic light falloff gives the rim a continuous bloom without blurring a full-screen image.
// contour: top corner radius, bottom corner radius, camera corner radius, camera is a pill.
[[ stitchable ]] half4 humEdgeGlow(float2 position, half4 color, float2 size, float4 camera,
                                   float4 contour, float scale, float time, float intensity,
                                   float4 glowColor) {
    if (intensity <= 0 || size.x <= 0 || size.y <= 0) return half4(0);
    float distance = edgeBox(position, float2(0), size, contour.x, contour.y);
    if (camera.z > 0 && camera.w > 0) {
        float cameraDistance = edgeBox(position, camera.xy, camera.zw,
                                       contour.w > 0.5 ? contour.z : 0, contour.z);
        distance = max(distance, -cameraDistance);
    }
    // No light is drawn in the physical camera housing or beyond the panel's corners.
    float visible = 1.0 - smoothstep(-0.5, 0.5, distance);
    // distance is signed: negative inside the screen rectangle, 0 at the border, positive outside.
    float unit = max(0.2, scale);
    float inward = max(0.0, -distance) / unit;
    float boost = clamp(intensity, 0.0, 3.0);

    // Map pixel position along the rectangular perimeter [0.0, 1.0)
    // Clockwise order: Top (L->R) -> Right (T->B) -> Bottom (R->L) -> Left (B->T)
    float dTop = position.y;
    float dBottom = size.y - position.y;
    float dLeft = position.x;
    float dRight = size.x - position.x;
    float minD = min(min(dTop, dBottom), min(dLeft, dRight));

    float totalPerimeter = max(1.0, 2.0 * (size.x + size.y));
    float s = 0.0;
    if (minD == dTop) {
        s = position.x;
    } else if (minD == dRight) {
        s = size.x + position.y;
    } else if (minD == dBottom) {
        s = size.x + size.y + (size.x - position.x);
    } else {
        s = 2.0 * size.x + size.y + (size.y - position.y);
    }
    float normS = fract(s / totalPerimeter);

    // Head of the travelling glow orbits perimeter once every ~6.0 seconds
    float headSpeed = 0.165; // ~6.06 seconds per complete lap around screen
    float headPos = fract(time * headSpeed);

    // Shortest distance along the circular perimeter [0.0, 0.5]
    float dHead = abs(normS - headPos);
    dHead = min(dHead, 1.0 - dHead);

    // Radiant head (~450-600pt along perimeter)
    // Sigma = 0.08 of perimeter (creates a vivid, prominent travelling comet)
    float headFactor = exp(-pow(dHead / 0.08, 2.0));

    // Trailing comet tail (extends behind the head along the direction of travel)
    // Travel direction is clockwise (increasing s), so tail is where s < headPos
    float tailDelta = fract(headPos - normS); // distance trailing behind head [0, 1)
    float tailFactor = exp(-tailDelta / 0.22) * (1.0 - smoothstep(0.0, 0.45, tailDelta)) * 0.70;

    // Contrast between the head and the rest of the perimeter:
    // The rest of the screen is dimmed (0.18 base brightness),
    // while the head and tail flare up to 1.0 (the full user-configured intensity level).
    float travelingIntensity = 0.18 + (headFactor * 0.82 + tailFactor * 0.35);
    travelingIntensity = clamp(travelingIntensity, 0.0, 1.0);

    // Glowing falloff inward into the display:
    // Crisp inner bezel rim (0-8 pt)
    float rim = exp(-pow(inward / (3.5 + boost * 1.5), 2.0));
    // Saturated aura (8-40 pt)
    float aura = exp(-inward / (14.0 + boost * 8.0)) * 0.90;
    // Ambient bloom (30-100 pt)
    float bloom = exp(-inward / (40.0 + boost * 25.0)) * 0.55;
    float haze = exp(-inward / (90.0 + boost * 40.0)) * 0.25;

    // Total glow at this pixel, modulated by travelingIntensity (head at full user intensity, rest dimmed)
    float baseGlow = (rim * 1.35 + aura + bloom + haze) * boost * visible;
    float glow = baseGlow * travelingIntensity;
    half alpha = half(clamp(glow, 0.0, 1.0));

    // Base dominant album color
    half3 baseColor = half3(glowColor.rgb);
    // At the head of the travelling beam, the innermost rim glows white-hot
    float coreWhite = clamp(rim * (0.6 + headFactor * 0.7), 0.0, 1.0);
    half3 tint = mix(baseColor, half3(1.0, 1.0, 1.0), half(coreWhite));
    return half4(tint * alpha, alpha);
}
