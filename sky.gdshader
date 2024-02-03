shader_type canvas_item;

varying vec2 world;
uniform vec2 range;
uniform vec3 bottomColor: source_color;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0, 1.0)).xy;
}

void fragment() {
	vec3 color = clamp((world.y - range.x) / (range.y - range.x), 0.0, 1.0) * bottomColor;
	COLOR = vec4(color, 1.0);
}
