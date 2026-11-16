## **THE LIGHT THE DISTRICT IS SEEN BY.** ADR-0026, GDD-05 §9. CLIENT ONLY.
##
## Late afternoon over a lagoon: a low warm sun, long cool shadows, haze toward the
## horizon. Chosen for ART_BIBLE §4's *value over hue* — readability comes from
## light against dark, and a low sun gives every figure a long shadow and every
## facade a lit side and a shaded one. It replaced the greybox's one key light and
## flat sky on 2026-11-16.
##
## **BUILT IN CODE, NOT IN THE SCENE**, so every colour comes from `WorldPalette`
## like the rest of the district, and so a palette can move the whole look.
class_name WorldLook
extends Node3D

const SKY := "res://assets/procedural/shaders/world_sky.gdshader"

## Where the sun stands, in degrees: its height above the horizon, and the turn of
## its light. From the south-west, so the long streets are half lit, half shaded.
const SUN_ELEVATION := 36.0
const SUN_YAW := -37.0
const SUN_ENERGY := 2.5
## How far the sun's shadows reach. The district is 120 m; beyond 90 m a shadow
## is a few pixels and the resolution is better spent near the player.
const SHADOW_REACH := 90.0

var palette: WorldPalette = null


func _ready() -> void:
	if palette == null:
		palette = WorldPalette.new()
	_raise_the_sun()
	_set_the_air()
	_smooth_the_edges()


func _raise_the_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-SUN_ELEVATION, SUN_YAW, 0.0)
	sun.light_color = palette.sunlight
	sun.light_energy = SUN_ENERGY
	sun.light_angular_distance = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = SHADOW_REACH
	sun.directional_shadow_blend_splits = true
	add_child(sun)


func _set_the_air() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = _sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.tonemap_white = 5.0
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.5
	env.ssao_enabled = true
	env.ssao_radius = 1.3
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	env.fog_enabled = true
	env.fog_light_color = palette.haze
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.35
	env.fog_sun_scatter = 0.2
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.06
	var holder := WorldEnvironment.new()
	holder.name = "WorldEnvironment"
	holder.environment = env
	add_child(holder)


func _sky() -> Sky:
	var material := ShaderMaterial.new()
	material.shader = load(SKY) as Shader
	material.set_shader_parameter(&"zenith", palette.sky_zenith)
	material.set_shader_parameter(&"horizon", palette.sky_horizon)
	material.set_shader_parameter(&"low_sky", palette.sky_low)
	material.set_shader_parameter(&"ground", palette.sky_ground)
	material.set_shader_parameter(&"sun_glow", palette.sun_glow)
	material.set_shader_parameter(&"cloud_lit", palette.cloud_lit)
	material.set_shader_parameter(&"cloud_shade", palette.cloud_shade)
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	return sky


## Thin trim against a bright sky is the worst case for a jagged edge, and the
## district is made of it.
func _smooth_the_edges() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.msaa_3d = Viewport.MSAA_4X
