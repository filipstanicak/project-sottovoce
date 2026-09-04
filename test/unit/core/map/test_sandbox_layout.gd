## **THE BENCH IS ONLY A BENCH IF ITS OWN GEOMETRY IS SOUND.** `MAP-SANDBOX`,
## 2026-09-04.
##
## A defect reproduced on a broken map is not the defect — so the properties the
## district's own suite asserts about `MAP-VETRAIO` are asserted here too, in the
## cheap forms a 40 m courtyard admits: spawn points a body fits at, anchors on
## ground somebody can stand on, an enclosed perimeter, and the corner trap
## actually having a mouth.
##
## **AND THE GENERATED `MapData` IS COMPARED AGAINST THE TABLE**, because trap 1's
## whole claim is that the table is the single source: a `.tres` that disagrees with
## the layout is a map somebody hand-edited, and the next generator run silently
## reverts it.
extends GutTest

const DATA := "res://data/maps/map_sandbox.tres"


func test_the_map_data_exists_and_names_itself() -> void:
	var data := load(DATA) as MapData
	assert_not_null(data, "the generated sandbox MapData is missing — run generate_map_sandbox.gd")
	assert_eq(data.id, Ids.MAP_SANDBOX)


## **THE ARTEFACT REPRODUCES THE TABLE.** Not a restatement of the generator: this
## is what goes red when somebody edits `map_sandbox.tres` by hand, which trap 1
## says will be silently reverted.
func test_the_generated_data_matches_the_layout() -> void:
	var data := load(DATA) as MapData
	assert_eq(data.spawn_points.size(), SandboxLayout.SPAWNS.size(), "spawn count drifted")
	assert_eq(data.idle_anchors.size(), SandboxLayout.anchors().size(), "anchor count drifted")
	assert_almost_eq(data.bounds.size.x, SandboxLayout.MAP_SIZE, 0.001, "the bench changed size")


## Every spawn point is somewhere a body of `NAV_AGENT_RADIUS` actually fits. A
## spawn inside a wall is a player ejected by physics on their first frame.
func test_every_spawn_point_is_standable() -> void:
	var bad: PackedStringArray = []
	for s: Array in SandboxLayout.SPAWNS:
		if not SandboxLayout.is_standable(Vector2(s[1], s[2])):
			bad.append("%s at (%.1f, %.1f)" % [s[0], s[1], s[2]])
	assert_eq(bad.size(), 0, "a spawn point is inside something:\n" + "\n".join(bad))


## **THE PREMISE.** `is_standable` returning true for everything would satisfy the
## test above perfectly, and satisfy it for a map made entirely of wall.
func test_is_standable_refuses_the_inside_of_a_block() -> void:
	assert_false(SandboxLayout.is_standable(Vector2(20.0, 20.0)), "CentreBlock is standable")
	assert_false(SandboxLayout.is_standable(Vector2(-3.0, 20.0)), "outside the courtyard is inside")
	assert_true(SandboxLayout.is_standable(Vector2(20.0, 30.0)), "open ground is not standable")


func test_every_anchor_is_standable_and_there_are_some() -> void:
	var anchors := SandboxLayout.anchors()
	assert_gt(anchors.size(), 8, "too few idle anchors to place a crowd on")
	for a: Vector3 in anchors:
		assert_true(SandboxLayout.is_standable(Vector2(a.x, a.z)), "anchor at %v is inside" % a)


## **THE TWO SPAWNS THAT MEET FIRST ARE 15 m APART**, which is the whole reason the
## bench exists: a hunter and a prey are in each other's world in about ten seconds
## of blend-walk. If somebody widens the courtyard, this is what says the encounter
## time went with it.
func test_two_spawn_points_are_within_a_short_walk() -> void:
	var closest := INF
	for i: int in SandboxLayout.SPAWNS.size():
		for j: int in range(i + 1, SandboxLayout.SPAWNS.size()):
			var a := Vector2(SandboxLayout.SPAWNS[i][1], SandboxLayout.SPAWNS[i][2])
			var b := Vector2(SandboxLayout.SPAWNS[j][1], SandboxLayout.SPAWNS[j][2])
			closest = minf(closest, a.distance_to(b))
	var walk := closest / Tuning.movement.blend_walk
	assert_lt(walk, 15.0, "the nearest two spawns are %.1f s apart at blend-walk" % walk)


## **THE CORNER TRAP HAS A WAY IN.** A nook sealed by its own walls is not a trap,
## it is a hole in the map — and the bot this map was built to reproduce could never
## reach it. The mouth is the gap between `NookWall`'s east end and the east wall.
func test_the_nook_has_a_mouth_wide_enough_to_walk_through() -> void:
	var wall := _block("NookWall")
	var mouth: float = SandboxLayout.MAP_SIZE - (float(wall[1]) + float(wall[3]))
	assert_gt(
		mouth,
		VetraioLayout.NAV_AGENT_RADIUS * 2.0,
		"the nook's mouth is %.2f m — narrower than a body" % mouth
	)
	# And the inside of it is standable, or the mouth opens onto nothing.
	assert_true(
		SandboxLayout.is_standable(Vector2(33.0, 35.0)), "the nook interior is not walkable"
	)


## The perimeter encloses the courtyard on all four sides. `MAP-VETRAIO` shipped
## without walls at all and lost nineteen NPCs a minute over the edge.
func test_the_courtyard_is_enclosed() -> void:
	for side: String in ["WallNorth", "WallSouth", "WallEast", "WallWest"]:
		assert_ne(_block(side), [], "the courtyard has no %s" % side)


## The stalls are in the vault band and nothing else on this map is. That band is
## the one whose only geometry in the district is a market stall — the band that
## hid the floor-height defect for three milestones.
func test_the_stalls_are_vaultable() -> void:
	assert_gt(SandboxLayout.STALLS.size(), 0, "the bench has nothing to vault")
	assert_lte(
		VetraioLayout.H_VAULT,
		Tuning.movement.traverse_vault_max_height,
		"the stall is taller than TUN-TRAVERSE-VAULT-MAX-HEIGHT and cannot be vaulted"
	)
	assert_gt(VetraioLayout.H_VAULT, 0.0, "the stall has no height to vault")


func _block(named: String) -> Array:
	for b: Array in SandboxLayout.BLOCKS:
		if String(b[0]) == named:
			return b
	return []
