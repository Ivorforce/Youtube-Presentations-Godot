shader_type canvas_item;

void fragment() {
	float d = 1.0 - UV.y;
	d = pow(d, 8);
	COLOR = vec4(vec3(1.0), min(15.0 - d * 15.0, d));
}
