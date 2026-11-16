// Value noise shared by every world shader. Hash-based, so the district needs no
// texture file: there is nothing to licence and nothing to stream.

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Four octaves, roughly 0..0.94 with a mean near 0.47.
float fbm(vec2 p) {
	float amplitude = 0.5;
	float sum = 0.0;
	for (int i = 0; i < 4; i++) {
		sum += amplitude * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return sum;
}

// Two octaves, for the places four would be paid for and not seen.
float fbm2(vec2 p) {
	return 0.62 * vnoise(p) + 0.38 * vnoise(p * 2.07 + vec2(5.3, 1.7));
}

// A running-bond cell: `id` of the brick `p` falls in and how far `p` is from
// that brick's edge, 0 at the joint and 0.5 at the middle of the short side.
float bond(vec2 p, vec2 size, out vec2 id) {
	vec2 q = p / size;
	float row = floor(q.y);
	q.x += 0.5 * mod(row, 2.0);
	id = vec2(floor(q.x), row);
	vec2 f = fract(q);
	vec2 edge = min(f, 1.0 - f) * size;
	return min(edge.x, edge.y);
}
