#[compute]
#version 450

#define M_PI 3.1415926535897932384626433832795

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Globals {
    uint seed;
    uint rayCount;
    uint bounceCount;
}
globals;

layout(set = 1, binding = 0, std430) restrict buffer Paths {
    float data[];
}
paths;

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


vec2 directionFromAngle(float rad) {
    return vec2(sin(rad), cos(rad));
}

////////////////////////////

void main() {
    uint bufIdx = gl_GlobalInvocationID.x * 3;
    vec2 position = vec2(Random(gl_GlobalInvocationID.x ^ globals.seed) * 2500.0 - 100, 0.0);
    vec2 direction = directionFromAngle(-0.2);
    float lightness = 1.0;

    paths.data[bufIdx] = position.x;
    paths.data[bufIdx + 1] = position.y;

    for (uint b = 1; b < globals.rayCount; b++) {
        bufIdx += globals.rayCount * 3;
        float distanceBeforeAtmosphereBounce = -log(1 - Random(gl_GlobalInvocationID.x ^ globals.seed ^ b)) / 0.001;
        
        if (direction.y > 0.0) {
            float bottomPos = 970.0;
            float distanceBeforeBottomBounce = (bottomPos - position.y) / direction.y;
            
            if (distanceBeforeBottomBounce < distanceBeforeAtmosphereBounce) {
                position += direction * distanceBeforeBottomBounce;

                paths.data[bufIdx] = position.x;
                paths.data[bufIdx + 1] = position.y;
                paths.data[bufIdx + 2] = lightness;

                direction = directionFromAngle(
                    Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b)
                    * M_PI + M_PI * 0.5
                );
                lightness *= 0.2;
                
                continue;
            }
        }
        
        position += direction * distanceBeforeAtmosphereBounce;
        
        paths.data[bufIdx] = position.x;
        paths.data[bufIdx + 1] = position.y;
        paths.data[bufIdx + 2] = lightness;
        
        direction = directionFromAngle(
            Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b)
            * 2.0 * M_PI
        );
        lightness *= 0.5;
    }
}
