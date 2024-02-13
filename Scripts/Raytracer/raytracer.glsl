#[compute]
#version 450

#define M_PI 3.1415926535897932384626433832795
#define M_SETUP_OUTSIDE 0
#define M_SETUP_INSIDE 1

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Globals {
    uint seed;
    uint rayCount;
    uint bounceCount;
    uint setup;
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

float lineInnerRectDistance(vec2 rayOrigin, vec2 rayDirection, vec2 rectMin, vec2 rectMax, out vec2 normal) {
    bool isXPositive = rayDirection.x > 0.0;
    float xDist = ((isXPositive ? rectMax : rectMin).x - rayOrigin.x) / rayDirection.x;
    
    bool isYPositive = rayDirection.y > 0.0;
    float yDist = ((isYPositive ? rectMax : rectMin).y - rayOrigin.y) / rayDirection.y;

    if (xDist < yDist) {
        normal = vec2(isXPositive ? -1 : 1, 0);
        return xDist;
    }
    else {
        normal = vec2(0, isYPositive ? -1 : 1);
        return yDist;
    }
}

////////////////////////////

void main() {
    // ray hue
    float rayHue = Random(gl_GlobalInvocationID.x ^ globals.seed ^ 21389182);
    rays.attributes[gl_GlobalInvocationID.x] = rayHue;

    uint bufIdx = gl_GlobalInvocationID.x * 4;

    float distToBlue = colorDist(rayHue, 0.65);
    float atmosphereDistToBounceFactor = 2000.0 + (200000.0 * distToBlue);
    
    vec2 direction;
    vec2 position;
    float lightness = 1.0;

    vec2 sphereCenter0 = vec2(1000, 500);
    
    if (globals.setup == M_SETUP_OUTSIDE) {
        direction = directionFromAngle(-0.1);

        vec2 line = vec2(-direction.y, direction.x);
        //    vec2 position = (Random(gl_GlobalInvocationID.x ^ globals.seed) * 200.0)  * line + vec2(1100.0, 0.0);
        position = ((Random(gl_GlobalInvocationID.x ^ globals.seed) - 0.74) * 1920.0 * 3) * line + vec2(1920.0, -10000.0) + line * 1920.0 / 2.0;
    }
    else {
        direction = directionFromAngle(Random(gl_GlobalInvocationID.x ^ globals.seed) * M_PI * 2);

        position = vec2(1000, 150) + direction * 5;
    }
    
    paths.data[bufIdx] = position.x;
    paths.data[bufIdx + 1] = position.y;
    paths.data[bufIdx + 2] = lightness;
    paths.data[bufIdx + 3] = 0.0;

    for (uint b = 1; b < globals.bounceCount; b++) {
        bufIdx += globals.rayCount * 4;
        
        int bounceTarget;
        float bounceDistance;
        vec2 bounceNormal;

        if (globals.setup == M_SETUP_OUTSIDE) {
            // Default bounce = atmosphere
            bounceTarget = 0; 
            bounceDistance = -log(1 - Random(gl_GlobalInvocationID.x ^ globals.seed ^ b)) * atmosphereDistToBounceFactor;
            bounceNormal = vec2(0, -1);

            if (direction.y > 0.0) {
                float bottomPos = 970.0;
                float distanceBeforeBottomBounce = (bottomPos - position.y) / direction.y;

                if (distanceBeforeBottomBounce < bounceDistance) {
                    bounceTarget = 1;
                    bounceDistance = distanceBeforeBottomBounce;
                    bounceNormal = vec2(0, -1);
                }
            }
        }
        else {
            bounceTarget = 1;
            bounceDistance = lineInnerRectDistance(position, direction, vec2(100, 100), vec2(1820, 980), bounceNormal);
        }

        float sphereDistance0 = closestLineCircleDistance(position, direction, sphereCenter0, 100);
        if (sphereDistance0 > 0 && sphereDistance0 < bounceDistance) {
            bounceDistance = sphereDistance0;
            bounceTarget = 2;
            bounceNormal = normalize(position + direction * sphereDistance0 - sphereCenter0);
        }
        
        ////

        position += direction * bounceDistance;

        if (bounceTarget == 1) {
            direction = rotate2D(
                bounceNormal,
                Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b) * M_PI - M_PI / 2
            );
            lightness *= 0.2;
        }
        else if (bounceTarget > 1) {
            direction = rotate2D(
                bounceNormal,
                Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b) * M_PI - M_PI / 2
            );
            lightness *= 0.8;
        }
        else {
            direction = directionFromAngle(
                Random((gl_GlobalInvocationID.x * globals.bounceCount) ^ globals.seed ^ 2632789429 ^ b) * M_PI * 2
            );
        }
        
        paths.data[bufIdx] = position.x;
        paths.data[bufIdx + 1] = position.y;
        paths.data[bufIdx + 2] = lightness;
        paths.data[bufIdx + 3] = float(bounceTarget);
    }
}
