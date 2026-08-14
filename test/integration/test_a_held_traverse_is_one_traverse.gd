## **HOLDING THE KEY MUST BE INDISTINGUISHABLE FROM TAPPING IT.** GDD-02 §7.3.
##
## The action buffer forgives an input pressed *early*. It is not a repeat rate.
## From US-0019 to US-0093 it armed from `InputCommand.buttons`, which is held
## state — so a finger resting on Space bought a fresh traverse every physics
## frame, and `TraversalResolver.resolve()` spent every one of them.
##
## Nothing showed until the hop existed, because the extra resolves had nothing
## to do. Then, at the controls: hop off a 0.9 m market stall with Space held and
## the pawn stops dead in the air. It had risen ~0.22 m, which is enough for the
## lip it just left to measure deeper than `TUN-TRAVERSE-DROP-MIN-HEIGHT` and
## classify as a gap jump — a planned interpolation, which zeroes the velocity.
##
## **THE ASSERTION IS THAT THE TWO TRAJECTORIES AGREE**, not that any particular
## number came out. A test that checked "the pawn kept moving" would pass on a
## pawn that gap-jumped somewhere plausible; a test that pinned the arc's length
## would fail the day a tunable moves. Same input, one press: same flight.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## On top of StallA (x 36–42, z 18–20, top 0.9 m), a little back from the far
## lip, facing +Z — the geometry the defect was found on.
const START := Vector3(39.0, 1.9, 18.4)
const LIP_Z := 19.5

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


## Walk off the stall pressing traverse at the lip, holding it or not. Returns
## the flight path, one entry per physics frame after the press.
func _fly(hold: bool) -> Array:
	var traverse: StringName = InputActions.action_names(Ids.INPUT_TRAVERSE)[0]
	_driver.ctx.body.global_position = START
	_driver.ctx.velocity = Vector3.ZERO
	for _i: int in 20:
		await get_tree().physics_frame

	Input.action_press(&"input_move_forward")
	var path: Array = []
	var pressed := false
	for _i: int in 45:
		if not pressed and _driver.ctx.position.z > LIP_Z:
			Input.action_press(traverse)
			pressed = true
		elif pressed and not hold:
			Input.action_release(traverse)
		await get_tree().physics_frame
		if pressed:
			path.append([_driver.ctx.position, _driver.ctx.state_id])
	Input.action_release(traverse)
	Input.action_release(&"input_move_forward")
	return path


func test_a_held_traverse_flies_the_same_arc_as_a_tapped_one() -> void:
	var tapped: Array = await _fly(false)
	var held: Array = await _fly(true)
	assert_gt(tapped.size(), 0, "the pawn never reached the lip — the geometry moved")
	assert_eq(held.size(), tapped.size(), "the two trials did not run for the same length")

	var worst := 0.0
	for i: int in tapped.size():
		worst = maxf(worst, (held[i][0] as Vector3).distance_to(tapped[i][0] as Vector3))
	assert_almost_eq(worst, 0.0, 0.01, "holding traverse flew a different arc from tapping it")


func test_a_held_traverse_does_not_re_resolve_in_mid_air() -> void:
	# The mechanism, named. A second resolve during the hop plans a manoeuvre, and
	# every manoeuvre state discards the pawn's momentum for a fixed interpolation.
	for step: Array in await _fly(true):
		assert_ne(
			step[1] as StringName,
			PawnStateId.DROP,
			"a held key resolved a second traverse in mid-air"
		)
