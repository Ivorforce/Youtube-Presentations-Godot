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

vec2 rotate2D(vec2 v, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Made by google gemini. ya I'm lazy
float closestLineCircleDistance(vec2 rayOrigin, vec2 rayDirection, vec2 circleCenter, float circleRadius) {
    vec2 oc = rayOrigin - circleCenter;
    float a = dot(rayDirection, rayDirection);
    float b = 2.0 * dot(rayDirection, oc);
    float c = dot(oc, oc) - circleRadius * circleRadius;

    // Solve the quadratic equation
    float discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
        // No intersection
        return -1.0;
    }

    float sqrt_discriminant = sqrt(discriminant);
    
    // Check for valid intersection (positive and in forward direction)
    float t1 = (-b - sqrt_discriminant) / (2.0 * a);
    float t2 = (-b + sqrt_discriminant) / (2.0 * a);
    if (t1 > 0.0) {
        return t1;
    } else if (t2 > 0.0) {
        return t2;
    }

    // No valid intersection
    return -1.0;
}

////////////////////////////

void main() {
    // ray hue
    float rayHue = Random(gl_GlobalInvocationID.x ^ globals.seed ^ 21389182);
    rays.attributes[gl_GlobalInvocationID.x] = rayHue;

    float distToBlue = colorDist(rayHue, 0.65);
    float atmosphereDistToBounceFactor = 2000.0 + (200000.0 * sqrt(distToBlue));

    uint bufIdx = gl_GlobalInvocationID.x * 4;
    vec2 direction = directionFromAngle(-0.1);
    vec2 line = vec2(-direction.y, direction.x);
//    vec2 position = (Random(gl_GlobalInvocationID.x ^ globals.seed) * 200.0)  * line + vec2(1100.0, 0.0);
    vec2 position = ((Random(gl_GlobalInvocationID.x ^ globals.seed) - 0.74) * 1920.0 * 3) * line + vec2(1920.0, -10000.0) + line * 1920.0 / 2.0;
    float lightness = 1.0;

    paths.data[bufIdx] = position.x;
    paths.data[bufIdx + 1] = position.y;
    paths.data[bufIdx + 2] = lightness;
    paths.data[bufIdx + 3] = 0.0;

    for (uint b = 1; b < globals.bounceCount; b++) {
        bufIdx += globals.rayCount * 4;
        float distanceBeforeAtmosphereBounce = -log(1 - Random(gl_GlobalInvocationID.x ^ globals.seed ^ b)) * atmosphereDistToBounceFactor;
        
        int bounceTarget = 0;
        float bounceDistance = distanceBeforeAtmosphereBounce;

        if (direction.y > 0.0) {
            float bottomPos = 970.0;
            float distanceBeforeBottomBounce = (bottomPos - position.y) / direction.y;

            if (distanceBeforeBottomBounce < distanceBeforeAtmosphereBounce) {
                bounceTarget = 1;
                bounceDistance = distanceBeforeBottomBounce;
            }
        }

        vec2 sphereCenter0 = vec2(1000, 500);
        float sphereDistance0 = closestLineCircleDistance(position, direction, sphereCenter0, 100);
        if (sphereDistance0 > 0 && sphereDistance0 < bounceDistance) {
            bounceDistance = sphereDistance0;
            bounceTarget = 2;
        }
        
        ////

        position += direction * bounceDistance;

        if (bounceTarget == 1) {
            direction = directionFromAngle(
                Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b)
                * M_PI + M_PI * 0.5
            );
            lightness *= 0.2;
        }
        else if (bounceTarget > 1) {
            direction = rotate2D(normalize(position - sphereCenter0), Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b) * M_PI - M_PI / 2);
            lightness *= 0.8;
        }
        else {
            direction = directionFromAngle(
                Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b)
                * 2.0 * M_PI
            );
        }
        
        paths.data[bufIdx] = position.x;
        paths.data[bufIdx + 1] = position.y;
        paths.data[bufIdx + 2] = lightness;
        paths.data[bufIdx + 3] = float(bounceTarget);
    }
}
