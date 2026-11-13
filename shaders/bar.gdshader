shader_type canvas_item;
// Rounded progress fill with a horizontal gradient across the filled part.
uniform vec4 col_a : source_color = vec4(0.55, 0.48, 1.0, 1.0);
uniform vec4 col_b : source_color = vec4(0.25, 0.94, 0.88, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec2 size = vec2(300.0, 8.0);

void fragment() {
	vec2 p = UV * size;
	float r = size.y * 0.5;
	float w = fill * size.x;
	float x = clamp(p.x, r, max(r, w - r));
	float d = length(vec2(p.x - x, p.y - r)) - r;
	float a = clamp(0.5 - d, 0.0, 1.0) * step(0.001, fill);
	vec3 c = mix(col_a.rgb, col_b.rgb, clamp(p.x / max(w, 1.0), 0.0, 1.0));
	COLOR = vec4(c, a);
}
