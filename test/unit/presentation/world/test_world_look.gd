## **THE DISTRICT HAS A SUN, A SKY AND AIR.** ADR-0026.
##
## The first client ever looked at rendered near-black, because nothing in the
## project had made a light (US-0091). The look is built in code now, so it can
## also be un-built by a refactor without a scene diff to show it.
extends GutTest

var _look: WorldLook


func before_each() -> void:
	_look = WorldLook.new()
	add_child_autofree(_look)


func test_there_is_one_sun_and_it_casts_shadows() -> void:
	var sun := _look.get_node_or_null("Sun") as DirectionalLight3D
	assert_not_null(sun)
	assert_true(sun.shadow_enabled, "a district without shadows has no depth")
	assert_gt(sun.light_energy, 0.0)


func test_the_sun_is_low_and_above_the_horizon() -> void:
	# Low enough for long shadows, high enough that a street is not all shade.
	var sun := _look.get_node("Sun") as DirectionalLight3D
	var down := -sun.global_transform.basis.z
	var elevation := rad_to_deg(asin(-down.y))
	assert_between(elevation, 25.0, 50.0)


func test_the_air_has_a_sky_that_lights_the_shade() -> void:
	var holder := _look.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_not_null(holder)
	var env := holder.environment
	assert_eq(env.background_mode, Environment.BG_SKY)
	assert_not_null(env.sky)
	assert_true(env.sky.sky_material is ShaderMaterial)
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_SKY)
	assert_gt(env.ambient_light_energy, 0.0)


func test_the_sky_takes_its_colours_from_the_palette() -> void:
	var palette := WorldPalette.new()
	palette.sky_zenith = palette.brick
	var look := WorldLook.new()
	look.palette = palette
	add_child_autofree(look)
	var env := (look.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as ShaderMaterial
	assert_eq(sky.get_shader_parameter(&"zenith"), palette.brick)
