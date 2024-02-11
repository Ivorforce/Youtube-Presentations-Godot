#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Globals {
    float distance;
    uint rayCount;
    uint bounceCount;
}
globals;

layout(set = 1, binding = 0, std430) restrict buffer Paths {
    float data[];
}
paths;

layout(set = 2, binding = 0, rgba32f) uniform image2D texture;

////////////////////////////

void main() {
    uint bufIdx = gl_GlobalInvocationID.x * 3;
    vec2 startPoint = vec2(paths.data[bufIdx], paths.data[bufIdx + 1]);
    float travelableDistance = globals.distance;

    for (int b = 1; b < globals.bounceCount; b++) {
        bufIdx += globals.rayCount * 3;

        vec2 endPoint = vec2(paths.data[bufIdx], paths.data[bufIdx + 1]);
        vec2 diffToEnd = endPoint - startPoint;
        float distToEnd = length(diffToEnd);
        float reachedRatio = travelableDistance / distToEnd;
        
        ivec2 pixelCoords = ivec2(startPoint + diffToEnd * min(reachedRatio, 1.0));
        vec4 curPixel = imageLoad(texture, pixelCoords);
        float curLightness = paths.data[bufIdx + 2];
        imageStore(
            texture, pixelCoords, vec4(min(vec3(1.0), max(curPixel.rgb, vec3(curLightness))), 1.0)
        );
        
        if (reachedRatio <= 1.0) {
            return;
        }
        
        startPoint = endPoint;
        travelableDistance -= distToEnd;
    }
}
