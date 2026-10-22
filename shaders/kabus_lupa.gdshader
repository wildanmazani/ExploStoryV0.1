shader_type canvas_item;
// Kabus Lupa: the forgotten past is grey. One rect over the whole world;
// fog_rects are the mission places not done yet (world pixels). Inside them
// the picture turns grey with a little light mist drifting across, with soft
// edges. The mini map and full map draw the same rects (world.fog_rects()).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 origin;
uniform vec2 size;
uniform vec4 clear_rects[16];   // x, y, w, h of the fogged places
uniform int clear_count = 0;
uniform float softness = 48.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 p = origin + UV * size;
	float k = 0.0;
	for (int i = 0; i < clear_count; i++) {
		vec4 r = clear_rects[i];
		if (r.z <= 0.0) {
			continue;
		}
		vec2 q = max(max(r.xy - p, p - (r.xy + r.zw)), vec2(0.0));
		k = max(k, 1.0 - smoothstep(0.0, softness, length(q)));   // 1 inside, fades out at the edge
	}
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	float drift = 0.5 + 0.5 * sin(TIME * 0.5 + p.x * 0.02 + p.y * 0.013);
	vec3 grey = mix(vec3(g), vec3(0.8, 0.82, 0.86), 0.22 + 0.1 * drift);
	vec3 col = mix(c, grey, k * 0.62);   // grey, but the place still shows through
	// a little light mist: soft pale banks drifting slowly across
	float mist = 0.5 + 0.25 * sin(p.x * 0.011 + TIME * 0.35) + 0.25 * sin(p.y * 0.017 - TIME * 0.27 + p.x * 0.004);
	col = mix(col, vec3(0.94, 0.95, 0.98), k * (0.10 + 0.16 * mist));
	COLOR = vec4(col, 1.0);
}
