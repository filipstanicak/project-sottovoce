## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **ONE LINE-OF-SIGHT QUERY, USED BY EVERYTHING.** TDD-07 §4.2, US-0056.
##
## `SCORE-FOCUS`, the Compass lock and Cinderfall occlusion all ask "can A see B".
## If each asked it its own way they would come to disagree — and the disagreement
## would be invisible, because each is right on its own terms. A player would earn
## Focus through a wall they could not lock through, or break a lock by stepping
## into a cloud that still let the kill validate.
##
## The rule they must share is not obvious and is easy to re-derive wrongly:
## **NPCs, players and corpses do not block sight** (GDD-03 §9.2), and a second
## query written from scratch would almost certainly include them, because
## including them is what every other game does.
##
## Why review misses this: the second query is three lines, it works, and it is
## written in a different file on a different day for a different feature.
extends GutTest

## Server-authoritative code. Presentation is excluded on purpose — the camera
## rig raycasts to pull itself out of walls, which is a rendering concern with no
## gameplay consequence, and `test_probes_mask_world_only.gd` already governs it.
const SERVER_ROOTS: Array[String] = [
	"res://scripts/systems",
	"res://scripts/net",
	"res://scripts/server",
]

## The one file allowed to raycast for visibility.
const CHOKEPOINT := "res://scripts/systems/detection/detection_system.gd"

const RAYCASTS: Array[String] = [
	"intersect_ray",
	"intersect_shape",
	"PhysicsRayQueryParameters3D",
	"direct_space_state",
]

const SERVER_SCENE := "res://scenes/server_root.tscn"
const SERVER_ROOT := "res://scripts/server/server_root.gd"


func _server_files() -> PackedStringArray:
	var found := PackedStringArray()
	for root: String in SERVER_ROOTS:
		for path: String in SourceScanner.gd_files(root):
			found.append(path)
	return found


func test_the_scan_reaches_server_code_at_all() -> void:
	# **THE VACUOUS-SUCCESS GUARD, FIRST.** A guard that walks nothing reports the
	# same thing as a codebase with nothing wrong in it.
	var files := _server_files()
	assert_gt(
		files.size(), 20, "the server scan found %d files, so it is not scanning" % files.size()
	)


func test_only_the_detection_system_raycasts() -> void:
	for path: String in _server_files():
		if path == CHOKEPOINT:
			continue
		for needle: String in RAYCASTS:
			assert_false(
				SourceScanner.code_contains(path, needle),
				(
					(
						"%s raycasts (%s). Line of sight is DetectionSystem.has_los() — a second "
						+ "query would come to disagree with it, invisibly, and each would be right."
					)
					% [path, needle]
				)
			)


func test_the_chokepoint_really_does_raycast() -> void:
	# **THE GUARD MUST NOT PASS BY THE QUERY HAVING BEEN DELETED.** Without this,
	# removing `has_los` outright would turn every assertion above green.
	assert_true(
		SourceScanner.code_contains(CHOKEPOINT, "intersect_ray"),
		"DetectionSystem no longer casts anything — the query is gone, not centralised"
	)


func test_the_query_masks_world_and_nothing_else() -> void:
	# **THE RULE IS THE MASK, NOT A FILTER.** NPCs and players sit on `PAWN`/`NPC`,
	# so a `WORLD` mask cannot see them however the query is written. Asked of the
	# object rather than of the text, because `SourceScanner` blanks string literals
	# and a numeric mask is easy to match by accident.
	var system := DetectionSystem.new()
	add_child_autofree(system)
	system.setup(MatchContext.new())
	var query := system.get("_query") as PhysicsRayQueryParameters3D
	assert_not_null(query, "DetectionSystem has no ray query to inspect")
	assert_eq(query.collision_mask, 1, "has_los masks more than WORLD — the crowd became solid")
	assert_false(query.collide_with_areas, "has_los collides with areas, which are not geometry")


func test_the_system_is_in_the_server_scene_and_registered() -> void:
	# **A CRITERION CAN BE TRUE OF A CLASS AND FALSE OF THE GAME.** `MatchDirector`
	# resolves systems by stage; one that is merely present in the scene is absent
	# from the order, and every render state would stay `PLAIN` for a whole match
	# with a green suite. It belongs in this file because a chokepoint nobody ticks
	# is not a chokepoint.
	assert_true(
		SourceScanner.read(SERVER_SCENE).contains("detection/detection_system.gd"),
		"server_root.tscn has no DetectionSystem"
	)
	assert_true(
		SourceScanner.code_contains(SERVER_ROOT, "director.register(detection)"),
		"server_root.gd never registers the DetectionSystem — present is not registered"
	)
