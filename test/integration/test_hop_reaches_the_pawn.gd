## Space in open ground lifts the pawn, through the real bindings. US-0093.
##
## The unit tests build an `InputCommand` by hand. This is the one that would
## notice if `INPUT-TRAVERSE` stopped reaching the resolver at all — which is
## exactly the wiring the boot suite exists for, and exactly what a hop is easy
## to get wrong in: the impulse is written to `ctx.velocity` inside `step()`, and
## `LocalPawnDriver` writes that velocity back from the physics body afterwards.
## A hop that never survived `move_and_slide` would pass every unit test.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

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


## Press traverse and report the highest the pawn reached above where it started.
func _hop_height() -> float:
	await _run(20)
	var ground := _driver.ctx.position.y
	Input.action_press(&"input_traverse")
	await _run(2)
	Input.action_release(&"input_traverse")
	var peak := ground
	for _i: int in 60:
		await get_tree().physics_frame
		peak = maxf(peak, _driver.ctx.position.y)
	return peak - ground


func test_space_in_open_ground_leaves_the_ground() -> void:
	var rise: float = await _hop_height()
	assert_gt(rise, 0.1, "Space in open ground did not lift the pawn at all")


func test_it_comes_back_down() -> void:
	# Gravity is the driver's, not the hop's. A pawn that kept rising would mean
	# the impulse was being re-applied, or that `grounded` never cleared.
	await _hop_height()
	await _run(90)
	assert_true(_driver.ctx.grounded, "the pawn never landed")


func test_running_hops_higher_than_standing() -> void:
	# **THE SHAPE, NOT THE MAGNITUDE.** The two tunables differ by design; what
	# this asserts is that the *state* is what selects between them, end to end.
	var standing: float = await _hop_height()

	await before_each()
	Input.action_press(&"input_move_forward")
	Input.action_press(&"input_run")
	await _run(30)
	assert_eq(_driver.ctx.state_id, PawnStateId.RUN, "the pawn never reached Run")
	var running: float = await _hop_height()

	assert_gt(running, standing, "running did not hop higher than standing")
