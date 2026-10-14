shader_type canvas_item;
// Applied to the ground TileMapLayer: only bluish "water" pixels shimmer,
// with drifting light bands and occasional sparkles. Sand and grass untouched.

uniform float band_strength = 0.05;
uniform float sparkle_strength = 0.22;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float water = step(c.r + 0.12, c.b) * step(c.r + 0.04, c.g);
	vec2 p = floor(world_pos); // stay on the pixel grid
	float w1 = sin(p.x * 0.30 + p.y * 0.18 + TIME * 1.6);
	float w2 = sin(p.y * 0.45 - p.x * 0.11 - TIME * 1.1);
	float band = w1 * w2;
	float sparkle = step(0.965, band) * step(0.5, fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453 + TIME * 0.4));
	c.rgb += water * (band * band_strength + sparkle * sparkle_strength);
	COLOR = c;
}
