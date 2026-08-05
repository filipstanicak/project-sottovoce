## Idle anchors deliver the density GDD-05 §3 promises, and the navmesh excludes
## what it must.
##
## DENSITY IS THE GAME'S SUBSTRATE (CLAUDE.md never-do #14). A pocket that drops
## below TUN-BLEND-POCKET-MIN-NPC *silently stops working* — the player believes
## they are blended and is not. That is the most dangerous silent failure in the
## game, so the anchor field is checked against the crowd budget rather than
## assumed to match it.
extends GutTest

const DATA := "res://data/maps/map_vetraio.tres"
const SAMPLE_STEP := 2.0  # GDD-05 test note: sample street level on a 2 m grid


func _data() -> MapData:
	var d: MapData = load(DATA)
	assert_not_null(d, "could not load " + DATA)
	return d


func test_the_anchor_count_fits_the_crowd_budget() -> void:
	# The check that matters. Declaring more anchors than there are NPCs to stand
	# on them makes every "dense" zone a promise the crowd system cannot keep.
	var d := _data()
	var idle_npcs := Tuning.crowd.count_default_6p - (4 * 4)  # 4 circuits x 4 walkers
	assert_gt(d.idle_anchors.size(), 0, "no idle anchors were placed")
	assert_lte(
		d.idle_anchors.size(),
		idle_npcs + 8,
		(
			(
				"%d anchors declared but only ~%d idle NPCs exist. A zone whose anchors "
				% [d.idle_anchors.size(), idle_npcs]
			)
			+ "cannot be filled is not dense, it only claims to be."
		)
	)


func test_every_dense_zone_can_actually_reach_pocket_minimum() -> void:
	# TUN-BLEND-POCKET-MIN-NPC within TUN-BLEND-POCKET-RADIUS. If a dense zone
	# cannot reach it from its own centre, the pocket module does not exist there.
	var d := _data()
	var radius := Tuning.suspicion.blend_pocket_radius
	var needed := Tuning.suspicion.blend_pocket_min_npc
	var failures: PackedStringArray = []
	for zone: MapZone in d.zones:
		if zone.density != MapZone.Density.DENSE:
			continue
		var centre := zone.bounds.position + zone.bounds.size * 0.5
		var found := d.anchors_near(Vector3(centre.x, 0.0, centre.z), radius)
		if found < needed:
			failures.append(
				(
					"%s has %d anchors within %.1f m, needs %d"
					% [zone.zone_name, found, radius, needed]
				)
			)
	assert_eq(
		failures.size(), 0, "A dense zone cannot form a blend pocket.\n" + "\n".join(failures)
	)


func test_no_anchor_sits_outside_the_map() -> void:
	var d := _data()
	var strays: PackedStringArray = []
	for anchor: Vector3 in d.idle_anchors:
		if anchor.x < 0.0 or anchor.x > VetraioLayout.MAP_SIZE:
			strays.append("%v" % anchor)
		elif anchor.z < 0.0 or anchor.z > VetraioLayout.MAP_SIZE:
			strays.append("%v" % anchor)
	assert_eq(strays.size(), 0, "anchors outside the map: " + ", ".join(strays))


func test_the_navmesh_excludes_roofs_balconies_and_the_canal() -> void:
	# Roofs and balconies are deliberately unreachable by NPCs — that is exactly
	# why standing on them costs suspicion. If an NPC could walk a roof, the roof
	# stratum would stop being a trade and become free ground.
	var d := _data()
	assert_gt(d.navmesh_exclusions.size(), 0, "no navmesh exclusions declared")

	var canal_point := Vector3(60.0, 0.0, 94.0)
	var roof_point := Vector3(15.0, VetraioLayout.ROOF_Y, 15.0)
	var street_point := Vector3(60.0, 0.0, 20.0)

	assert_true(_excluded(d, canal_point), "the canal must be excluded")
	assert_true(_excluded(d, roof_point), "roofs must be excluded")
	assert_false(_excluded(d, street_point), "street level must NOT be excluded")


func test_street_level_is_sampled_and_mostly_open() -> void:
	# A 2 m grid over the playable extent. This is a coverage sanity check, not a
	# true navmesh query — baking is a scene operation and this suite is pure.
	var d := _data()
	var inside := 0
	var excluded := 0
	var x := 1.0
	while x < VetraioLayout.MAP_SIZE:
		var z := 1.0
		while z < VetraioLayout.MAP_SIZE:
			inside += 1
			if _excluded(d, Vector3(x, 0.0, z)):
				excluded += 1
			z += SAMPLE_STEP
		x += SAMPLE_STEP
	assert_gt(inside, 1000, "the sample grid is too coarse to mean anything")
	assert_lt(
		float(excluded) / float(inside),
		0.15,
		"more than 15%% of street level is excluded — the canal should be ~3%%"
	)


static func _excluded(d: MapData, point: Vector3) -> bool:
	for box: AABB in d.navmesh_exclusions:
		if box.has_point(point):
			return true
	return false
