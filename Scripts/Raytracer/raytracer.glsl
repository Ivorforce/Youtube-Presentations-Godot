#[compute]
#version 450

#define M_PI 3.1415926535897932384626433832795

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Globals {
    uint seed;
    uint rayCount;
    uint bounceCount;
}
globals;

layout(set = 1, binding = 0, std430) restrict writeonly buffer Paths {
    float data[];
}
paths;

layout(set = 1, binding = 1, std430) restrict writeonly buffer Rays {
    float attributes[];
}
rays;

////////////////////////////

// Hash function from H. Schechter & R. Bridson, goo.gl/RXiKaH
uint Hash(uint s)
{
    s ^= 2747636419u;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    return s;
}

float Random(uint seed)
{
    return float(Hash(seed)) / 4294967295.0; // 2^32-1
}

////////////////////////////


vec2 directionFromAngle(float rad) {
    return vec2(sin(rad), cos(rad));
}

float colorDist(float hue1, float hue2) {
    float d = abs(hue1 - hue2);
    return d < 0.5 ? d : (1.0 - d);
}

////////////////////////////

void main() {
    // ray hue
    float rayHue = Random(gl_GlobalInvocationID.x ^ globals.seed ^ 21389182);
    rays.attributes[gl_GlobalInvocationID.x] = rayHue;

    float distToBlue = colorDist(rayHue, 0.64);
    float atmosphereDistToBounceFactor = 10.0 + (50000.0 * distToBlue);
    float distToFloorColor = colorDist(rayHue, 0.375);

    uint bufIdx = gl_GlobalInvocationID.x * 3;
    vec2 direction = directionFromAngle(-0.1);
    vec2 line = vec2(-direction.y, direction.x);
    vec2 position = (Random(gl_GlobalInvocationID.x ^ globals.seed) * 200.0)  * line + vec2(1100.0, 0.0);
    float lightness = 0.5;

    paths.data[bufIdx] = position.x;
    paths.data[bufIdx + 1] = position.y;
    paths.data[bufIdx + 2] = lightness;

    for (uint b = 1; b < globals.bounceCount; b++) {
        bufIdx += globals.rayCount * 3;
        float distanceBeforeAtmosphereBounce = -log(1 - Random(gl_GlobalInvocationID.x ^ globals.seed ^ b)) * atmosphereDistToBounceFactor;
        
        if (direction.y > 0.0) {
            float bottomPos = 970.0;
            float distanceBeforeBottomBounce = (bottomPos - position.y) / direction.y;
            
            if (distanceBeforeBottomBounce < distanceBeforeAtmosphereBounce) {
                position += direction * distanceBeforeBottomBounce;
                
                direction = directionFromAngle(
                    Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b)
                    * M_PI + M_PI * 0.5
                );
                lightness *= (1.0 - pow(distToFloorColor, 2)) * 0.1;

                paths.data[bufIdx] = position.x;
                paths.data[bufIdx + 1] = position.y;
                paths.data[bufIdx + 2] = lightness;

                continue;
            }
        }
        
        position += direction * distanceBeforeAtmosphereBounce;
        
        direction = directionFromAngle(
            Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b)
            * 2.0 * M_PI
        );
        lightness *= 0.95;

        paths.data[bufIdx] = position.x;
        paths.data[bufIdx + 1] = position.y;
        paths.data[bufIdx + 2] = lightness;
    }
}
