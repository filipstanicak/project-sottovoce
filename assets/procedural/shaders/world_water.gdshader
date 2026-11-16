// The lagoon and the canals: one plane under the whole district.
shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

#include "world_noise.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.07, 0.11, 0.10);
uniform vec3 shallow : source_color = vec3(0.20, 0.27, 0.25);
uniform float wave_height = 0.22;

varying vec3 world_position;

float swell(vec2 p) {
	float a = fbm2(p * vec2(0.5, 0.9) + TIME * vec2(0.05, 0.03));
	float b = fbm2(p * vec2(2.6, 1.9) - TIME * vec2(0.08, 0.06));
	return a * 0.6 + b * 0.4;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float span = 0.12;
	float here = swell(p);
	float east = swell(p + vec2(span, 0.0));
	float south = swell(p + vec2(0.0, span));
	// Ripples flatten with distance, or the far lagoon turns to glitter noise.
	float calm = 1.0 - smoothstep(30.0, 160.0, length(VERTEX));
	float steep = wave_height * calm;
	vec3 normal = normalize(vec3(-(east - here) / span * steep, 1.0, -(south - here) / span * steep));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	float facing = clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	ALBEDO = mix(deep, shallow, clamp(fresnel * 0.6 + (here - 0.45) * 0.5, 0.0, 1.0));
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	METALLIC = 0.35;
}
