## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **A CRITERION CAN BE TRUE OF A CLASS AND FALSE OF THE GAME.** US-0039 ticked
## "ninety bodies allocated once" while `server_root.tscn` held no `NpcPool` at
## all: the pool was real, its tests passed, and ninety bodies were allocated in
## the suite and nowhere else. This guard is that lesson, applied to every piece
## of the crowd in turn.
##
## Three things a scene or a call site has to say, none of which any unit test
## can see:
##
##   1. `npc_server.tscn` has a navigation agent, or steering has nothing to steer.
##   2. `server_root.tscn` has a `CrowdDirector`, or nothing ticks a brain.
##   3. `server_root.gd` *registers* it, because a system merely present in the
##      scene is a system `MatchDirector` has never heard of and will never call.
##
## Why review misses this: each half looks complete on its own. The class is
## written, tested and reviewed; the scene is edited in a different file on a
## different day; and nothing anywhere fails when the two never meet.
extends GutTest

const NPC_SCENE := "res://scenes/npc/npc_server.tscn"
const SERVER_SCENE := "res://scenes/server_root.tscn"
const SERVER_ROOT := "res://scripts/server/server_root.gd"


func test_the_scenes_exist_to_be_scanned() -> void:
	# Guards the guard: a path typo makes every assertion below vacuously green.
	assert_ne(SourceScanner.read(NPC_SCENE), "", "npc_server.tscn is missing")
	assert_ne(SourceScanner.read(SERVER_SCENE), "", "server_root.tscn is missing")


func test_the_npc_scene_carries_a_navigation_agent() -> void:
	assert_true(
		SourceScanner.read(NPC_SCENE).contains('type="NavigationAgent3D"'),
		(
			"npc_server.tscn has no NavigationAgent3D.\n"
			+ "Steering configures one per NPC and would silently steer nothing."
		)
	)


func test_the_server_scene_carries_the_crowd_director() -> void:
	var scene := SourceScanner.read(SERVER_SCENE)
	assert_true(
		scene.contains("crowd/crowd_director.gd"),
		"server_root.tscn has no CrowdDirector — nothing would tick a brain"
	)
	assert_true(
		scene.contains("crowd/npc_pool.gd"),
		"server_root.tscn has no NpcPool — this is US-0039's failure, verbatim"
	)


func test_the_server_registers_the_crowd_director() -> void:
	# **PRESENT IS NOT REGISTERED.** `MatchDirector._run_stage` looks a system up
	# by stage; one that never registered is simply absent from the order, and the
	# crowd would stand still with a full, correct, green crowd suite.
	assert_true(
		SourceScanner.code_contains(SERVER_ROOT, "director.register(crowd_director)"),
		(
			"server_root.gd never registers the CrowdDirector.\n"
			+ "A system in the scene that nobody registers is ticked by nobody."
		)
	)


func test_the_director_rebuilds_the_shared_hash() -> void:
	# **THE HASH IS ON `MatchContext` SO FOUR SYSTEMS CAN REACH IT** — and a hash
	# nobody rebuilds is a grid that answers every query with the crowd's opening
	# positions, for eight minutes, without erroring. `test_crowd_moves.gd` proves
	# it is current; this proves there is exactly one place that makes it so.
	assert_true(
		SourceScanner.code_contains(
			"res://scripts/systems/crowd/crowd_director.gd", "crowd_hash.rebuild("
		),
		"CrowdDirector never rebuilds ctx.crowd_hash"
	)
	assert_true(
		SourceScanner.code_contains("res://scripts/systems/match_context.gd", "SpatialHash.new()"),
		"MatchContext does not own the shared hash"
	)


func test_the_director_claims_the_crowd_stage() -> void:
	# And that the stage it claims is one a system may occupy at all — `ingest`,
	# `pawn` and `snapshot` are positions in the order, and the director refuses
	# them.
	assert_true(
		SystemOrder.is_a_system_stage(&"crowd"), "the crowd stage stopped being a system stage"
	)
	# Read raw rather than scanned: `code_lines` blanks string literals, and the
	# thing being matched IS one. A scan the wrong way round is green forever.
	assert_true(
		SourceScanner.read("res://scripts/systems/crowd/crowd_director.gd").contains(
			'return &"crowd"'
		),
		"CrowdDirector does not claim the crowd stage"
	)
