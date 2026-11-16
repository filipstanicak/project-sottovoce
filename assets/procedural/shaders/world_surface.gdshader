// Every built surface in the district that is not ground or water: plaster, the
// coursed stone of a climbable facade, trim, timber, cloth, roof tile, iron, glass.
//
// ONE SHADER, EIGHT KINDS, so the district is a handful of materials and batches.
// Everything is mapped in world space: a pattern does not stretch with its box,
// and two boxes that meet share their courses.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "world_noise.gdshaderinc"

// 0 plaster, 1 coursed stone, 2 plain stone, 3 timber, 4 cloth, 5 roof tile,
// 6 iron, 7 glass.
uniform int kind = 0;
uniform vec3 base_colour : source_color = vec3(0.8);
uniform vec3 second_colour : source_color = vec3(0.5);
uniform vec3 top_colour : source_color = vec3(0.6, 0.42, 0.34);
uniform vec3 top_joint : source_color = vec3(0.4, 0.36, 0.33);
uniform float glow = 1.6;
instance uniform vec3 tint : source_color = vec3(1.0);
instance uniform float seed = 0.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Relief of the surface at `uv`, 0..1, for the kinds that have any.
float relief(vec2 uv) {
	vec2 id;
	if (kind == 1) {
		return smoothstep(0.0, 0.035, bond(uv, vec2(0.72, 0.36), id));
	}
	if (kind == 5) {
		// Pantiles: half-round ridges running down the slope, lapped in rows.
		float ridge = abs(sin(uv.x * 3.14159 / 0.22));
		float lap = fract(uv.y / 0.34);
		return ridge * 0.8 + lap * 0.2;
	}
	if (kind == 3) {
		return smoothstep(0.0, 0.01, bond(uv.yx, vec2(3.0, 0.17), id));
	}
	return fbm2(uv * 7.0);
}

vec3 plaster(vec2 uv, vec3 colour, float height, out float rough) {
	float cloud = fbm(uv * 0.42 + seed);
	vec3 c = colour * (0.84 + 0.3 * cloud);
	// Rain streaks from above, rising damp from below.
	float streak = fbm2(vec2(uv.x * 1.6 + seed, uv.y * 0.16));
	c *= mix(1.0, 0.8, smoothstep(0.5, 0.85, streak));
	float damp = smoothstep(0.0, 1.2, height + (fbm2(uv * 1.4) - 0.5) * 0.7);
	c *= mix(0.7, 1.0, damp);
	// Where the render has fallen away the brick shows. Never at eye height,
	// which ART_BIBLE 4.1 keeps quiet.
	float fallen = smoothstep(0.69, 0.72, fbm(uv * 0.33 + seed * 7.1));
	fallen *= clamp(step(2.6, height) + step(height, 1.0), 0.0, 1.0);
	vec2 id;
	float brick = smoothstep(0.0, 0.012, bond(uv, vec2(0.26, 0.075), id));
	vec3 exposed = mix(second_colour * 0.6, second_colour * (0.8 + 0.4 * hash12(id)), brick);
	rough = mix(0.93, 0.88, fallen);
	return mix(c, exposed, fallen);
}

vec3 coursed(vec2 uv, vec3 colour, float height, out float rough) {
	vec2 id;
	float d = bond(uv, vec2(0.72, 0.36), id);
	float face = smoothstep(0.0, 0.03, d);
	// A course finer than a pixel is shimmer: its stones fade to their mean.
	float grain = max(fwidth(uv.x), fwidth(uv.y));
	float tone = mix(0.5, hash12(id), 1.0 - smoothstep(0.1, 0.4, grain));
	face = mix(1.0, face, 1.0 - smoothstep(0.02, 0.1, grain));
	vec3 c = colour * (0.8 + 0.34 * tone) * (0.88 + 0.24 * fbm(uv * 0.5 + seed));
	c *= mix(0.76, 1.0, smoothstep(0.0, 1.0, height));
	rough = mix(0.96, 0.84, face);
	return mix(second_colour, c, face);
}

vec3 terrace(vec2 uv, out float rough) {
	vec2 id;
	float d = bond(uv, vec2(0.32, 0.32), id);
	float grain = max(fwidth(uv.x), fwidth(uv.y));
	float face = mix(1.0, smoothstep(0.0, 0.014, d), 1.0 - smoothstep(0.012, 0.06, grain));
	float tone = mix(0.5, hash12(id), 1.0 - smoothstep(0.08, 0.3, grain));
	rough = mix(0.95, 0.8, face);
	vec3 tile = top_colour * (0.82 + 0.32 * tone) * (0.9 + 0.2 * fbm(uv * 0.3));
	return mix(top_joint, tile, face);
}

vec3 timber(vec2 uv, vec3 colour) {
	vec2 id;
	float plank = smoothstep(0.0, 0.01, bond(uv.yx, vec2(3.0, 0.17), id));
	float grain = fbm2(vec2(uv.x * 2.0, uv.y * 26.0) + hash12(id) * 9.0);
	return colour * (0.72 + 0.36 * grain) * (0.86 + 0.22 * hash12(id)) * mix(0.55, 1.0, plank);
}

vec3 pantile(vec2 uv, vec3 colour) {
	float tile = hash12(vec2(floor(uv.x / 0.22), floor(uv.y / 0.34)));
	float ridge = abs(sin(uv.x * 3.14159 / 0.22));
	return colour * (0.74 + 0.38 * tile) * mix(0.62, 1.0, ridge) * (0.9 + 0.2 * fbm(uv * 0.4));
}

void fragment() {
	vec3 n = normalize(world_normal);
	bool up = n.y > 0.7;
	bool along_z = abs(n.x) > abs(n.z);
	vec2 wall_uv = along_z ? world_position.zy : world_position.xy;
	vec2 uv = up ? world_position.xz : wall_uv;
	if (kind == 5) {
		// Tiles run down the slope, whichever way the roof falls.
		float fall = world_position.y * 1.6;
		uv = along_z ? vec2(world_position.z, world_position.x * 0.5 + fall) : vec2(world_position.x, world_position.z * 0.5 + fall);
	}
	vec3 wall_tangent = along_z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = up ? vec3(1.0, 0.0, 0.0) : wall_tangent;
	vec3 bitangent = up ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 colour = base_colour * tint * COLOR.rgb;
	float near = 1.0 - smoothstep(20.0, 55.0, length(VERTEX));
	float rough = 0.9;
	float bump = 0.0;
	vec3 albedo = colour;
	if (kind == 7) {
		albedo = base_colour;
		rough = 0.12;
		EMISSION = COLOR.rgb * glow * (0.75 + 0.25 * vnoise(uv * 3.0));
		SPECULAR = 0.8;
	} else if (up && kind <= 1) {
		albedo = terrace(uv, rough) * COLOR.rgb;
		bump = 0.02;
	} else if (kind == 0) {
		albedo = plaster(uv, colour, world_position.y, rough);
		bump = 0.012;
	} else if (kind == 1) {
		albedo = coursed(uv, colour, world_position.y, rough);
		bump = 0.05;
	} else if (kind == 2) {
		albedo = colour * (0.86 + 0.26 * fbm(uv * 0.9 + seed));
		albedo *= 0.94 + 0.12 * vnoise(uv * 40.0) * near;
		rough = 0.88;
		bump = 0.008;
	} else if (kind == 3) {
		albedo = timber(uv, colour);
		rough = 0.82;
		bump = 0.03;
	} else if (kind == 4) {
		float stripe = step(0.5, fract(uv.x / 0.56));
		float fold = fbm2(vec2(uv.x * 0.8, uv.y * 3.0));
		albedo = mix(colour, second_colour * tint, stripe) * (0.82 + 0.3 * fold);
		rough = 0.96;
	} else if (kind == 5) {
		albedo = pantile(uv, colour);
		rough = 0.9;
		bump = 0.06;
	} else if (kind == 6) {
		albedo = colour * (0.8 + 0.3 * fbm2(uv * 5.0));
		rough = 0.55;
		METALLIC = 0.7;
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	if (bump > 0.0 && near > 0.01) {
		float span = 0.01;
		float here = relief(uv);
		float du = (relief(uv + vec2(span, 0.0)) - here) / span;
		float dv = (relief(uv + vec2(0.0, span)) - here) / span;
		vec3 bent = normalize(n - (tangent * du + bitangent * dv) * bump * near);
		NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	}
}
