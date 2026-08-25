## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **A CRITERION CAN BE TRUE OF A CLASS AND FALSE OF THE GAME.** US-0039 ticked
## "ninety bodies allocated once" while `server_root.tscn` held no `NpcPool`; the
## same shape is available to US-0052's first criterion, *"runs once per net
## tick"*, which is false of a system nobody registered — and true of every unit
## test in `test_suspicion_system.gd`, all of which call `tick()` themselves.
##
## `MatchDirector` looks a system up **by stage**. One that is merely present in
## the scene is absent from the order: no error, no log line, and a whole match in
## which nobody's suspicion ever moves off zero while the suite is green.
##
## Why review misses this: the class is written, tested and reviewed on one day;
## the scene is a different file edited on another; and nothing anywhere fails
## when the two never meet.
extends GutTest

const SERVER_SCENE := "res://scenes/server_root.tscn"
const SERVER_ROOT := "res://scripts/server/server_root.gd"
const SYSTEM := "res://scripts/systems/suspicion/suspicion_system.gd"


func test_the_files_exist_to_be_scanned() -> void:
	# Guards the guard: a path typo makes every assertion below vacuously green.
	assert_ne(SourceScanner.read(SERVER_SCENE), "", "server_root.tscn is missing")
	assert_ne(SourceScanner.read(SYSTEM), "", "suspicion_system.gd is missing")


func test_the_server_scene_carries_the_suspicion_system() -> void:
	assert_true(
		SourceScanner.read(SERVER_SCENE).contains("suspicion/suspicion_system.gd"),
		"server_root.tscn has no SuspicionSystem — nobody's suspicion would ever move"
	)


func test_the_server_registers_it() -> void:
	assert_true(
		SourceScanner.code_contains(SERVER_ROOT, "director.register(suspicion)"),
		(
			"server_root.gd never registers the SuspicionSystem.\n"
			+ "Present in the scene is not registered: MatchDirector resolves by stage."
		)
	)


func test_it_reaches_the_crowd_through_the_shared_hash_and_never_through_physics() -> void:
	# **US-0052's SECOND CRITERION, STRUCTURALLY.** A shape query would be a second
	# answer to a question `ctx.crowd_hash` already holds — six of them a tick,
	# against a world the hash was built from at the top of the same tick. It would
	# also be *right*, most of the time, which is what makes it survivable enough to
	# ship.
	assert_true(
		SourceScanner.code_contains(SYSTEM, "crowd_hash.nearest_distance("),
		"SYS-SUSPICION does not ask the shared spatial hash for the nearest NPC"
	)
	for banned: String in [
		"intersect_ray",
		"intersect_shape",
		"get_world_3d",
		"PhysicsDirectSpaceState",
		"PhysicsServer3D"
	]:
		assert_false(
			SourceScanner.code_contains(SYSTEM, banned),
			"SYS-SUSPICION reaches for %s — the crowd is asked once, through the hash" % banned
		)


func test_the_system_declares_the_stage_the_document_puts_it_at() -> void:
	# The stage string is what `MatchDirector` resolves on and what `SystemOrder`
	# orders. A system naming a stage nothing declares registers into nothing.
	# **ASKED OF THE OBJECT, NOT OF THE TEXT.** `SourceScanner` blanks string
	# literals so a guard is never tripped by its own documentation — which means a
	# scan for the stage name matches the blank it leaves behind and passes on any
	# file at all. Trap 3's family, caught by this assertion failing on correct code.
	var system := SuspicionSystem.new()
	var stage := system.stage()
	system.free()
	assert_eq(stage, &"suspicion", "SYS-SUSPICION does not name the suspicion stage")
	assert_true(
		SystemOrder.is_a_system_stage(stage), "`%s` is not a stage a system may occupy" % stage
	)
