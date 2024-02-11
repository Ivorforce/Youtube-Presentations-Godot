#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Globals {
    float distance;
}
globals;

layout(set = 1, binding = 0, std430) restrict buffer Paths {
    float data[];
}
paths;

layout(set = 2, binding = 0, rgba32f) writeonly uniform image2D texture;

////////////////////////////

void main() {
    uint buf_idx = gl_GlobalInvocationID.x * 2;
    imageStore(
        texture,
        ivec2(uint(paths.data[buf_idx] * 1920.0 * globals.distance), uint(paths.data[buf_idx + 1] * 1080.0 * globals.distance)),
        vec4(1.0, 0.0, 0.0, 1.0)
    );
}
