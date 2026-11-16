// Every walkable surface: street setts, piazza paving and the balcony boards.
//
// KEPT LIGHT AND LOW IN CONTRAST ON PURPOSE. The blend net (US-0107) is a faint
// white line on this ground, and the owner asked for a light grey floor so it
// reads. The pattern is carried by relief and joint lines, not by value.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "world_noise.gdshaderinc"

uniform vec3 stone_a : source_color = vec3(0.56, 0.55, 0.53);
uniform vec3 stone_b : source_color = vec3(0.64, 0.63, 0.60);
uniform vec3 joint : source_color = vec3(0.40, 0.39, 0.38);
uniform vec3 band : source_color = vec3(0.76, 0.75, 0.71);
uniform vec3 board : source_color = vec3(0.45, 0.36, 0.27);
uniform vec3 side : source_color = vec3(0.60, 0.59, 0.56);
// 0 street setts, 1 piazza paving, 2 timber boards.
instance uniform float pattern = 0.0;

varying vec3 world_position;
varying vec3 world_normal;

// Height of the surface at `p`, 0 in a joint and 1 on a stone, with the stone id.
float relief(vec2 p, out vec2 id) {
	if (pattern > 1.5) {
		float d = bond(p.yx, vec2(2.4, 0.18), id);
		return smoothstep(0.0, 0.012, d);
	}
	if (pattern > 0.5) {
		float d = bond(p, vec2(0.64, 0.4), id);
		return smoothstep(0.0, 0.016, d);
	}
	float d = bond(p, vec2(0.24, 0.15), id);
	return smoothstep(0.0, 0.03, d);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (world_normal.y < 0.7) {
		vec2 face = vec2(world_position.x + world_position.z, world_position.y);
		ALBEDO = side * (0.8 + 0.3 * fbm2(face * 1.3));
		ROUGHNESS = 0.92;
	} else {
		vec2 p = world_position.xz;
		// Detail fades with distance: a pattern finer than a pixel is only shimmer.
		float near = 1.0 - smoothstep(22.0, 60.0, length(VERTEX));
		vec2 id;
		float h = relief(p, id);
		vec2 unused;
		float span = 0.012;
		float east = relief(p + vec2(span, 0.0), unused);
		float south = relief(p + vec2(0.0, span), unused);
		float wear = fbm(p * 0.16);
		// A stone finer than a pixel is shimmer: joints and tones fade to their mean.
		float grain = max(fwidth(p.x), fwidth(p.y));
		float tone = mix(0.5, hash12(id), 1.0 - smoothstep(0.08, 0.3, grain));
		float crisp = 1.0 - smoothstep(0.012, 0.07, grain);
		vec3 stone = mix(stone_a, stone_b, tone) * (0.9 + 0.2 * wear);
		if (pattern > 1.5) {
			stone = board * (0.82 + 0.3 * tone) * (0.9 + 0.2 * fbm2(vec2(p.x * 9.0, p.y * 0.7)));
		} else if (pattern > 0.5) {
			// Pale bands every 7.5 m, the way a piazza is ruled into fields.
			vec2 cell = abs(fract(p / 7.5 + 0.5) - 0.5) * 7.5;
			float ruled = 1.0 - smoothstep(0.21, 0.24, min(cell.x, cell.y));
			stone = mix(stone, band * (0.94 + 0.1 * wear), ruled);
		}
		ALBEDO = mix(stone, mix(stone, joint, 0.6), (1.0 - h) * crisp);
		ROUGHNESS = mix(0.95, 0.72 + 0.12 * tone, mix(1.0, h, crisp));
		float steep = 0.05 * near * crisp;
		vec3 bent = vec3(-(east - h) / span * steep, 1.0, -(south - h) / span * steep);
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(bent), 0.0)).xyz);
	}
}
