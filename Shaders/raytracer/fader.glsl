#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Globals {
    float multiplier;
}
globals;

layout(set = 1, binding = 0, rgba32f) uniform image2D texture;

////////////////////////////

void main() {
    imageStore(
        texture,
        ivec2(gl_GlobalInvocationID.xy),
        imageLoad(texture, ivec2(gl_GlobalInvocationID.xy)) * globals.multiplier
    );
}
