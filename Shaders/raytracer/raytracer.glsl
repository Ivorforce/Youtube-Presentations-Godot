#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Globals {
    uint seed;
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

////////////////////////////

void main() {
    uint buf_idx = gl_GlobalInvocationID.x * 2;
    paths.data[buf_idx * 2] = Random(gl_GlobalInvocationID.x ^ globals.seed);
    paths.data[buf_idx * 2 + 1] = Random(gl_GlobalInvocationID.x ^ globals.seed ^ 3187238917);
}
