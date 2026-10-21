shader_type canvas_item;
// Kabus Lupa: the forgotten past is grey.
// mode 0 (Lembah, Bab 2): fog over the whole valley except inside clear_rects
//   (finished missions), fading in over the sea strait.
// mode 1 (Bab 1 island): fog only inside clear_rects (missions still to do).
// Soft edges either way. Rects are in world pixels.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 origin;
uniform vec2 size;
uniform vec4 clear_rects[8];   // x, y, w, h
uniform int clear_count = 0;
uniform float softness = 40.0;
uniform int mode = 0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 p = origin + UV * size;
	float k = mode == 0 ? 1.0 : 0.0;
	for (int i = 0; i < clear_count; i++) {
		vec4 r = clear_rects[i];
		vec2 q = max(max(r.xy - p, p - (r.xy + r.zw)), vec2(0.0));
		float d = length(q);   // 0 inside the rect, grows outside
		if (mode == 0) {
			k = min(k, smoothstep(0.0, softness, d));
		} else if (r.z > 0.0) {
			k = max(k, 1.0 - smoothstep(0.0, softness, d));
		}
	}
	if (mode == 0) {
		k *= smoothstep(0.0, 64.0, UV.x * size.x);   // fade in over the sea strait
	}
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	float drift = 0.5 + 0.5 * sin(TIME * 0.5 + p.x * 0.02 + p.y * 0.013);
	vec3 grey = mix(vec3(g), vec3(0.8, 0.82, 0.86), 0.22 + 0.1 * drift);
	COLOR = vec4(mix(c, grey, k * 0.85), 1.0);
}
