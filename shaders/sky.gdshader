shader_type sky;
// Vertical deep-space gradient behind the cavern.
uniform vec3 top : source_color = vec3(0.110, 0.063, 0.275);
uniform vec3 mid : source_color = vec3(0.047, 0.039, 0.149);
uniform vec3 bottom : source_color = vec3(0.027, 0.071, 0.145);

void sky() {
	float t = clamp(EYEDIR.y * 2.6 * 0.5 + 0.5, 0.0, 1.0);
	COLOR = t > 0.5 ? mix(mid, top, (t - 0.5) * 2.0) : mix(bottom, mid, t * 2.0);
}
