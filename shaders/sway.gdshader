shader_type canvas_item;
// Wind sway for trees and bushes: the top of the sprite moves, the base stays.
// Offset is snapped to whole pixels so the pixel art never smears.

uniform float strength = 1.5;
uniform float speed = 1.4;

void vertex() {
	float top = 1.0 - UV.y;
	float phase = MODEL_MATRIX[3].x * 0.05 + MODEL_MATRIX[3].y * 0.03;
	float gust = sin(TIME * speed + phase) + 0.4 * sin(TIME * speed * 2.3 + phase * 1.7);
	VERTEX.x += floor(gust * strength * top * top + 0.5);
}
