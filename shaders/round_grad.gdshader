shader_type canvas_item;
// A rounded rectangle filled with a left-to-right gradient (the main menu's Play button).
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec2 box = vec2(380.0, 84.0);
uniform float radius = 24.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 h = box * 0.5;
	vec2 q = abs(lp - h) - (h - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float a = clamp(0.5 - d, 0.0, 1.0);
	vec3 g = mix(c1.rgb, c2.rgb, clamp(lp.x / box.x, 0.0, 1.0));
	// a soft top highlight
	g += vec3(0.08) * (1.0 - smoothstep(0.0, 0.5, lp.y / box.y));
	COLOR = vec4(g, a * COLOR.a);
}
