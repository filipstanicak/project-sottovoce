// The district's sky: a late-afternoon gradient, the sun's glow and still clouds.
//
// NO `TIME` HERE, ON PURPOSE. A sky shader that reads the clock makes the engine
// re-render the radiance map every frame, and the whole district is lit from that
// map. Still clouds cost nothing after the first frame.
shader_type sky;

#include "world_noise.gdshaderinc"

uniform vec3 zenith : source_color = vec3(0.24, 0.40, 0.66);
uniform vec3 horizon : source_color = vec3(0.90, 0.78, 0.64);
uniform vec3 low_sky : source_color = vec3(0.56, 0.72, 0.90);
uniform vec3 ground : source_color = vec3(0.30, 0.31, 0.33);
uniform vec3 sun_glow : source_color = vec3(1.0, 0.74, 0.46);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.94, 0.86);
uniform vec3 cloud_shade : source_color = vec3(0.56, 0.58, 0.68);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.36;

float cloud_field(vec2 p) {
	return fbm(p * 0.55 + vec2(3.0, 11.0)) + 0.18 * fbm(p * 2.6);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	// Three bands: the warm haze at the horizon, a pale blue above it, the zenith.
	float lift = clamp(up, 0.0, 1.0);
	vec3 colour = mix(horizon, low_sky, smoothstep(0.0, 0.16, lift));
	colour = mix(colour, zenith, smoothstep(0.08, 0.85, lift));
	if (up < 0.0) {
		colour = mix(horizon, ground, smoothstep(0.0, -0.22, up));
	}
	float toward_sun = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	colour += sun_glow * (pow(toward_sun, 6.0) * 0.28 + pow(toward_sun, 48.0) * 0.5);
	if (up > 0.0) {
		vec2 p = dir.xz / (up + 0.14);
		float thick = cloud_field(p);
		float low = 1.0 - cloud_cover * 0.75;
		float cover = smoothstep(low - 0.13, low + 0.06, thick);
		// Lit where the cloud thins toward the sun, shaded where it thickens.
		float toward = cloud_field(p + normalize(LIGHT0_DIRECTION.xz + vec2(0.001)) * 0.35);
		float lit = clamp(0.55 + (thick - toward) * 3.0, 0.0, 1.0);
		vec3 cloud = mix(cloud_shade, cloud_lit, lit) + sun_glow * pow(toward_sun, 5.0) * 0.35;
		colour = mix(colour, cloud, cover * smoothstep(0.0, 0.16, up) * 0.9);
	}
	if (!AT_CUBEMAP_PASS) {
		colour += LIGHT0_COLOR * smoothstep(0.99955, 0.9998, toward_sun) * 6.0;
	}
	COLOR = colour;
}
