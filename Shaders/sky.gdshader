shader_type canvas_item;

varying vec2 world;
uniform vec2 range;
uniform vec3 bottomColor: source_color;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0, 1.0)).xy;
}

void fragment() {
	float h = clamp((world.y - range.x) / (range.y - range.x), 0.0, 1.0);
	vec3 color = pow(h, 2) * bottomColor;
	COLOR = vec4(color, 1.0);
}
