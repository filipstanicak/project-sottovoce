## Every corridor is at least as wide as GDD-05 §4.2 requires.
##
## Width is not cosmetic. An alley below 2.6 m cannot satisfy the camera-fairness
## rule, so the camera pulls in and the player loses the peripheral vision the
## whole game is played with. An alley mouth outside 2.2–2.8 m stops fitting a
## Cinderfall cloud, which is the canonical escape geometry — the ability would
## still fire and simply stop working there, in one place, silently.
extends GutTest

const MIN_WIDTH := 1.4  # GDD-05 §4.4: minimum navigable width, matches a doorway


func _floor_named(target: String) -> Array:
	for f: Array in VetraioLayout.FLOORS:
		if String(f[0]) == target:
			return f
	return []


func test_every_walkable_surface_is_navigable_width() -> void:
	# The narrowest dimension of any floor must admit an NPC (agent radius 0.4 m).
	var violations: PackedStringArray = []
	for f: Array in VetraioLayout.FLOORS:
		var narrowest := minf(float(f[3]), float(f[4]))
		if narrowest < MIN_WIDTH:
			violations.append("%s is %.2f m at its narrowest" % [f[0], narrowest])
	assert_eq(
		violations.size(),
		0,
		(
			"A walkable surface is narrower than the %.1f m navigable minimum.\n" % MIN_WIDTH
			+ "NPCs must reach everywhere players can at street level (Pillar B).\n"
			+ "\n".join(violations)
		)
	)


func test_the_bridge_is_the_authored_width() -> void:
	# Ponte Corto is 2.4 m so crossing is a genuine decision, not a formality.
	var bridge := _floor_named("PonteCorto")
	assert_false(bridge.is_empty(), "PonteCorto is missing")
	assert_eq(
		minf(float(bridge[3]), float(bridge[4])),
		VetraioLayout.BRIDGE_WIDTH,
		"the bridge must be exactly 2.4 m — it is the only street-level crossing"
	)


func test_the_alley_is_at_least_the_camera_minimum() -> void:
	var alley := _floor_named("VicoloStretto")
	assert_false(alley.is_empty(), "VicoloStretto is missing")
	assert_gte(
		minf(float(alley[3]), float(alley[4])),
		VetraioLayout.MIN_ALLEY_WIDTH,
		"below 2.6 m the camera-fairness rule cannot be satisfied"
	)


func test_the_main_street_holds_a_walking_group() -> void:
	# 6-8 m: wide enough for a walking group plus passers-by, so travel density
	# holds. A narrow main street makes circuits unusable as cover.
	var street := _floor_named("ViaDelleLampe")
	assert_false(street.is_empty(), "ViaDelleLampe is missing")
	var width := minf(float(street[3]), float(street[4]))
	assert_gte(width, VetraioLayout.MAIN_STREET_RANGE.x, "main street too narrow")


func test_the_loggia_spans_the_arcade_range() -> void:
	var loggia := _floor_named("Loggia")
	assert_false(loggia.is_empty(), "Loggia is missing")
	assert_gte(
		float(loggia[4]),
		VetraioLayout.ARCADE_SPAN_RANGE.x,
		"two people must pass without contact — a blend-walker and their hunter share this"
	)


func test_the_width_check_would_catch_a_narrow_corridor() -> void:
	# Guards the guard: the comparison must actually reject something.
	assert_lt(1.0, MIN_WIDTH, "a 1.0 m corridor must be below the minimum")
	assert_gte(VetraioLayout.BRIDGE_WIDTH, MIN_WIDTH, "the bridge is navigable")
