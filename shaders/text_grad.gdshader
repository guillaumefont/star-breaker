shader_type canvas_item;
// Gradient-filled text. mode 0: three stops left to right, mode 1: two stops top to bottom.
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform int mode = 0;
uniform vec2 box = vec2(400.0, 80.0);
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 g;
	if (mode == 0) {
		float t = clamp(lp.x / box.x, 0.0, 1.0);
		g = t < 0.5 ? mix(c1.rgb, c2.rgb, t * 2.0) : mix(c2.rgb, c3.rgb, t * 2.0 - 1.0);
	} else {
		float t = clamp(lp.y / box.y, 0.0, 1.0);
		g = mix(c1.rgb, c2.rgb, smoothstep(0.3, 1.0, t));
	}
	COLOR = vec4(g, COLOR.a);
}
