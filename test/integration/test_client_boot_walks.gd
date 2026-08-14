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


func test_the_pawn_stands_on_the_ground_and_does_not_fall() -> void:
	# **US-0016 COULD NOT TELL WALKING FROM FALLING.** Its movement test asserted
	# only that the pawn had travelled more than half a metre, which a pawn
	# dropping through the world satisfies handsomely.
	#
	# It was falling. The capsule was centred on the body origin, so placing the
	# origin on a spawn point buried the pawn to the waist; `MapData.spawn_points`
	# and `TUN-TRAVERSE-PROBE-HEIGHT-*` are both measured from the ground, and the
	# scene disagreed with both. US-0017's probes are what noticed — they reported
	# no floor under a pawn standing in the middle of the district.
	var start := _driver.ctx.position.y
	await _run(FRAMES)
	assert_almost_eq(_driver.ctx.position.y, start, 0.2, "the pawn is falling through the map")
	assert_true(_driver.ctx.grounded, "the pawn never found the floor")


func test_walking_forward_moves_horizontally_and_not_downward() -> void:
	# The other half of the same hole. Distance alone cannot distinguish the two.
	var start := _driver.ctx.position
	Input.action_press(&"input_move_forward")
	await _run(FRAMES)
	var moved := _driver.ctx.position - start
	assert_gt(Vector2(moved.x, moved.z).length(), 0.5, "the pawn did not travel along the ground")
	assert_lt(absf(moved.y), 0.5, "the pawn's travel was mostly vertical")


## **THE KEY THAT MOVES YOU RIGHT MUST MOVE YOU RIGHT.** Through the real
## `InputMap`, because the unit tests build an `InputCommand` by hand and cannot
## see a binding that reaches the wrong axis.
##
## `ProbeLayout.right(ctx.yaw)`, never a literal `+X`. The pawn spawns at yaw 0
## and the two are the same number there, which is exactly how a swapped pair
## hides: an assertion written as a world axis is true of both frames.
func _assert_travel(action: StringName, wanted: Vector3, what: String) -> void:
	var start := _driver.ctx.position
	Input.action_press(action)
	await _run(FRAMES)
	var moved := _driver.ctx.position - start
	var flat := Vector3(moved.x, 0.0, moved.z)
	assert_gt(flat.length(), 0.5, "%s moved the pawn nowhere" % what)
	assert_gt(flat.normalized().dot(wanted.normalized()), 0.98, "%s went the wrong way" % what)


func test_d_walks_to_the_pawns_right() -> void:
	await _assert_travel(&"input_move_right", ProbeLayout.right(_driver.ctx.yaw), "D")


func test_a_walks_to_the_pawns_left() -> void:
	await _assert_travel(&"input_move_left", -ProbeLayout.right(_driver.ctx.yaw), "A")


func test_w_walks_where_the_pawn_faces() -> void:
	await _assert_travel(&"input_move_forward", ProbeLayout.forward(_driver.ctx.yaw), "W")


func test_the_probes_run_against_the_real_map() -> void:
	# `test_traversal_probes_geometry.gd` proves the casts work against boxes this
	# suite built. This proves they are wired into the driver and pointed at
	# MAP-VETRAIO — the pawn is standing on the district's floor, and the probes
	# can see it.
	await _run(2)
	var probe: ProbeResult = _driver.ctx.probe_result
	assert_true(probe.valid, "the probes never ran in the real client scene")
	assert_true(probe.ground_ahead, "the probes cannot see the ground the pawn is standing on")
	assert_false(probe.at_edge(), "a pawn on a spawn point reads as standing at a cliff")


func test_the_probes_refresh_before_the_state_machine_steps() -> void:
	# TDD-06 §4: raycasts are only valid in the physics step, and a state casting
	# its own would cast again on every reconciliation replay — the same query
	# against a world that has since moved on.
	#
	# Scanned in `PawnMotion` since US-0028, because that is where the order now
	# lives — and the move is why it matters more, not less: the SERVER runs these
	# same lines, so an inversion here would put the two peers a frame apart on
	# every probe, which is a divergence in prediction rather than a local bug.
	var source := SourceScanner.read("res://scripts/pawn/pawn_motion.gd")
	var refresh := source.find("probes.refresh(")
	var step := source.find("machine.step(")
	assert_gt(refresh, -1, "the driver does not refresh the probes")
	assert_lt(refresh, step, "the probes refresh AFTER step() — the states read last frame")


func test_pressing_traverse_at_a_real_wall_puts_the_pawn_over_it() -> void:
	# **THE WHOLE POINT OF US-0019**, through the real driver, the real machine and
	# the real binding. A vault that works in a unit test and not here is a vault
	# nobody can perform.
	# Let the pawn settle onto the map floor FIRST. Built against the spawn
	# position instead, the wall sits 0.1 m low — and a 0.9 m wall whose waist
	# probe sits at 0.85 has only 5 cm of margin, so it reads as no wall at all.
	await _run(6)
	var start := _driver.ctx.position
	_wall_in_front(0.9)
	await _run(2)

	Input.action_press(&"input_traverse")
	await _run(2)
	Input.action_release(&"input_traverse")
	assert_eq(_driver.ctx.state_id, PawnStateId.VAULT, "a traverse at a 0.9 m wall did not vault")

	await _run(Tuning.step_ticks(&"TUN-TRAVERSE-VAULT-DURATION") + 8)
	assert_eq(_driver.ctx.state_id, PawnStateId.IDLE, "the pawn never came out of the vault")
	assert_gt(
		_driver.ctx.position.z - start.z, 0.9, "the pawn is still on the near side of the wall"
	)


func test_pressing_traverse_at_a_real_facade_climbs_it() -> void:
	# The other end of the resolver, through the same real chain as the vault.
	# A 4 m face is §7.4's "climb, always" — above the mantle ceiling, well inside
	# the one-stratum limit.
	await _run(6)
	var start := _driver.ctx.position
	_wall_in_front(4.0)
	await _run(2)

	Input.action_press(&"input_traverse")
	await _run(2)
	Input.action_release(&"input_traverse")
	assert_eq(_driver.ctx.state_id, PawnStateId.CLIMB, "a traverse at a 4 m façade did not climb")

	# 4 m at TUN-SPEED-CLIMB is about 1.4 s; allow the arrival plus slack.
	await _run(int(4.0 / Tuning.movement.climb * Tuning.net.client_input_rate) + 20)
	assert_eq(_driver.ctx.state_id, PawnStateId.IDLE, "the pawn never reached the top")
	assert_gt(_driver.ctx.position.y - start.y, 3.0, "the pawn is still at the bottom of the wall")


func test_a_traverse_in_an_empty_street_produces_no_manoeuvre() -> void:
	# **CASE 7 CHANGED IN US-0093, AND THIS TEST CHANGED WITH IT.** It used to
	# assert that an empty street did nothing *at all*, which was case 7 as
	# written — "silence, not a flail". Space now hops there, and the part of the
	# claim that survives is the part that mattered: no manoeuvre, no state
	# change, and no horizontal displacement. The hop is an impulse, and
	# `test_hop_reaches_the_pawn.gd` owns the vertical half.
	var before := _driver.ctx.position
	Input.action_press(&"input_traverse")
	await _run(6)
	Input.action_release(&"input_traverse")
	assert_eq(_driver.ctx.state_id, PawnStateId.IDLE, "an empty street produced a manoeuvre")
	var moved := _driver.ctx.position - before
	assert_almost_eq(
		Vector2(moved.x, moved.z).length(), 0.0, 0.05, "the hop carried the pawn along the ground"
	)


## A `height`-tall wall 0.7 m in front of the pawn, standing on the ground the
## pawn is standing on — so call this only once the pawn has settled.
func _wall_in_front(height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, height, 0.4)
	shape.shape = box
	body.add_child(shape)
	_root.get_node("World").add_child(body)
	body.global_position = _driver.ctx.position + Vector3(0.0, height * 0.5, 0.7)


func test_the_reconciliation_buffer_fills_as_the_pawn_is_driven() -> void:
	# The client-only half of the dual buffer. It is filled now, before US-0033
	# replays from it, because a buffer whose first use is also its first test is
	# a buffer nobody has tested.
	await _run(4)
	assert_gt(_driver.history().size(), 0, "no input reached the reconciliation buffer")
	assert_true(
		_driver.history().size() <= _driver.history().capacity(), "the buffer grew past its bound"
	)
