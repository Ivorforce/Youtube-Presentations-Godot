shader_type canvas_item;

float length_sq(vec2 v) {
	return dot(v, v);
} 

void fragment() {
	float d = length_sq(UV - 0.5) * 4.0;
	
	if (d > 1.0) {
		discard;
	}

	d = pow(d, 16);
	
	// Baller antialiasing
	COLOR = vec4(vec3(1.0), min(20.0 - d * 20.0, d));
}
