## No dead end is longer than 8 m, and the map's affordances are where GDD-05
## says they are.
##
## A player committing to a dead end must be able to see its end from its mouth.
## Longer than that and the death that follows feels like a map bug rather than a
## decision — which is the one failure the level design cannot afford, because the
## whole game asks the player to trust that space is legible.
extends GutTest

const DATA := "res://data/maps/map_vetraio.tres"


func _data() -> MapData:
	var d: MapData = load(DATA)
	assert_not_null(d, "could not load " + DATA)
	return d


func test_the_map_data_exists_and_is_identified() -> void:
	var d := _data()
	assert_eq(d.id, &"MAP-VETRAIO")
	assert_eq(d.bounds.size.x, VetraioLayout.MAP_SIZE)
	assert_eq(d.bounds.size.z, VetraioLayout.MAP_SIZE)


func test_no_walkable_surface_is_a_long_dead_end() -> void:
	# A floor is dead-end shaped when it is long and narrow. Anything longer than
	# 8 m on its long axis while below the arcade span is checked for a second
	# opening; the layout has none, so the rule reduces to a length bound.
	var violations: PackedStringArray = []
	for f: Array in VetraioLayout.FLOORS:
		var long_axis := maxf(float(f[3]), float(f[4]))
		var short_axis := minf(float(f[3]), float(f[4]))
		var is_corridor := short_axis <= VetraioLayout.ARCADE_SPAN_RANGE.y
		# Open at both ends, so length is not a commitment. Listed by name rather
		# than by widening the rule, because "long and narrow" is exactly the
		# shape the rule exists to catch.
		var is_through_route := (
			String(f[0]) in ["PonteCorto", "FondacoStreet", "EastStreet", "LoggiaBalcony", "Loggia"]
		)
		if is_corridor and not is_through_route and long_axis > VetraioLayout.MAX_DEAD_END:
			violations.append("%s is %.1f m long and %.1f m wide" % [f[0], long_axis, short_axis])
	assert_eq(
		violations.size(),
		0,
		(
			"A corridor longer than %.1f m has no second exit.\n" % VetraioLayout.MAX_DEAD_END
			+ "A player must see a dead end's end from its mouth.\n"
			+ "\n".join(violations)
		)
	)


func test_there_are_exactly_six_spawns_and_they_are_far_apart() -> void:
	var d := _data()
	assert_eq(d.spawn_count(), 6, "TUN-SPAWN-POINT-COUNT is 6 — one per player at max lobby")
	assert_gte(
		d.min_spawn_separation(),
		30.0,
		"two players respawning at once must not land in each other's kill range"
	)


func test_no_spawn_is_in_a_theatre_space() -> void:
	# GDD-05 §2.7 rule 5: you never begin a life already accruing suspicion.
	var d := _data()
	var offenders: PackedStringArray = []
	for i: int in d.spawn_points.size():
		for theatre: AABB in d.theatre_spaces:
			var flat := AABB(
				Vector3(theatre.position.x, -1.0, theatre.position.z),
				Vector3(theatre.size.x, 2.0, theatre.size.z)
			)
			if flat.has_point(Vector3(d.spawn_points[i].x, 0.0, d.spawn_points[i].z)):
				offenders.append("spawn %d is inside a theatre space" % i)
	assert_eq(offenders.size(), 0, "\n".join(offenders))


func test_the_four_circuits_exist_with_their_periods() -> void:
	var d := _data()
	assert_eq(d.circuits.size(), 4, "TUN-CROWD-GROUP-COUNT is 4")
	assert_eq(d.circuit_periods.size(), 4, "every circuit needs a period")
	for i: int in d.circuit_periods.size():
		assert_between(d.circuit_periods[i], 55.0, 75.0, "circuit %d period out of range" % i)
	for i: int in d.circuits.size():
		assert_gt(d.circuits[i].size(), 2, "circuit %d is not a loop" % i)


func test_no_circuit_enters_piazza_secca() -> void:
	# The empty plaza staying empty is its entire function. A circuit through it
	# would hand a player mobile cover in the one place that must have none.
	var d := _data()
	var secca := AABB(Vector3(34.0, -1.0, 60.0), Vector3(56.0, 2.0, 30.0))
	var offenders: PackedStringArray = []
	for i: int in d.circuits.size():
		for p: Vector3 in d.circuits[i]:
			if secca.has_point(Vector3(p.x, 0.0, p.z)):
				offenders.append("circuit %d passes through Piazza Secca at %v" % [i, p])
	assert_eq(offenders.size(), 0, "\n".join(offenders))


func test_the_five_blend_props_exist() -> void:
	assert_eq(_data().blend_props.size(), 5, "GDD-05 §2.4 specifies five concealment props")


func test_the_two_theatre_spaces_exist() -> void:
	assert_eq(_data().theatre_spaces.size(), 2, "GDD-05 §5.3 specifies two")


func test_a_theatre_space_has_no_idle_anchors() -> void:
	# An audience needs an unobstructed stage. Anchors in Piazza Secca would give
	# a crossing player cover in the space whose emptiness IS the mechanic.
	var d := _data()
	var offenders := 0
	for zone: MapZone in d.zones:
		if not zone.is_theatre:
			continue
		for anchor: Vector3 in d.idle_anchors:
			if zone.bounds.has_point(Vector3(anchor.x, zone.bounds.position.y, anchor.z)):
				offenders += 1
	assert_eq(offenders, 0, "%d idle anchors were placed inside a theatre space" % offenders)
