## **A KEY PRESS MOVES THE PAWN.** End to end, through the real client scene.
##
## The first test in this project that boots a scene, and it exists because of
## what happened when none did: the whole boot path was broken —
## `change_scene_to_file` from `_ready()` fails while the tree is still building
## — with 92 unit tests green, and the only way anyone found out was launching
## the game. US-0016 hit the same class of defect again on its first run: a spawn
## routed through `transition()` looked up `Respawning`, which does not exist
## until US-0062, and took the boot down with 222 tests passing.
##
## Unit tests prove `step()` is correct. They cannot prove anything ever CALLS
## it. This does.
##
## Deliberately end-to-end: the real `client_root.tscn`, the real
## `InputSampler`, the real `InputMap` bindings from `project.godot`. A double
## anywhere in that chain would let the exact wiring bug this exists to catch
## through.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Long enough for acceleration to produce a visible distance, short enough that
## the pawn cannot cross the district. `TUN-SPEED-ACCEL` reaches stroll in well
## under this.
const FRAMES := 40

var _root: Node
var _driver: LocalPawnDriver


func before_each() -> void:
	_release_everything()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


func _run(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


func test_the_client_scene_boots_with_a_driven_pawn() -> void:
	assert_not_null(_driver, "client_root.tscn has no LocalPawnDriver")
	assert_not_null(_driver.ctx.body, "the driver is not attached to a body")
	assert_eq(_driver.ctx.state_id, PawnStateId.IDLE, "the pawn did not spawn into Idle")


func test_it_spawns_on_a_declared_spawn_point() -> void:
	# Not at the origin, which is a corner of the map and where a pawn ends up
	# when the spawn lookup silently fails.
	var map := load("res://data/maps/map_vetraio.tres") as MapData
	assert_gt(map.spawn_count(), 0, "MAP-VETRAIO declares no spawn points")
	assert_almost_eq(
		_driver.ctx.position.distance_to(map.spawn_points[0]),
		0.0,
		1.0,
		"the pawn did not spawn on S1"
	)


func test_pressing_forward_actually_moves_the_pawn() -> void:
	# THE ASSERTION THE WHOLE FILE IS FOR. Everything before US-0016 could compute
	# a velocity; nothing delivered one an input had caused.
	var start := _driver.ctx.position
	Input.action_press(&"input_move_forward")
	await _run(FRAMES)
	assert_gt(
		_driver.ctx.position.distance_to(start), 0.5, "a held movement key moved the pawn nowhere"
	)


func test_walking_reaches_stroll_and_not_blend_walk() -> void:
	# GDD-02 §2.2: default movement is Stroll. Blend-walk is a deliberate act.
	Input.action_press(&"input_move_forward")
	await _run(FRAMES)
	assert_eq(_driver.ctx.state_id, PawnStateId.STROLL, "unmodified movement is not Stroll")


func test_the_slow_key_reaches_blend_walk() -> void:
	# The most important key in the game, through the real binding. If
	# `project.godot` and `InputActions` ever disagreed about its name, every
	# unit test would still pass and this is what would notice.
	Input.action_press(&"input_move_forward")
	await _run(FRAMES)
	Input.action_press(&"input_slow")
	await _run(2)
	assert_eq(_driver.ctx.state_id, PawnStateId.BLEND_WALK, "INPUT-SLOW did not blend-walk")


func test_releasing_movement_returns_to_idle() -> void:
	Input.action_press(&"input_move_forward")
	await _run(FRAMES)
	Input.action_release(&"input_move_forward")
	await _run(FRAMES)
	assert_eq(_driver.ctx.state_id, PawnStateId.IDLE, "the pawn did not stop")


func test_the_reconciliation_buffer_fills_as_the_pawn_is_driven() -> void:
	# The client-only half of the dual buffer. It is filled now, before US-0033
	# replays from it, because a buffer whose first use is also its first test is
	# a buffer nobody has tested.
	await _run(4)
	assert_gt(_driver.history().size(), 0, "no input reached the reconciliation buffer")
	assert_true(
		_driver.history().size() <= _driver.history().capacity(), "the buffer grew past its bound"
	)
