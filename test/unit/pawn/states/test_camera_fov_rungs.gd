## **WHICH RUNG EACH STATE SITS ON.** GDD-02 §4.2, US-0022.
##
## The ladder lives on the STATES, not in a table inside the camera. That is the
## design position this file defends: the rung is a consequence of the decision
## the player made — pressing run, releasing slow — and not of the velocity the
## physics happens to be reporting. A rig that mapped speed to FOV itself would
## widen during every acceleration ramp, while the pawn was still labelled Stroll
## and still paying Stroll's suspicion rate, and the lens would be reporting a
## different fact from the meter.
extends GutTest

var _machine: PawnStateMachine
var _ctx: PawnContext


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())
	_ctx = PawnContext.new()


func after_each() -> void:
	_machine.free()


func _fov(id: StringName) -> float:
	_ctx.state_id = id
	return _machine.camera_fov(_ctx)


## Every value a state is allowed to answer with. The four rungs §4.2 names, plus
## `TUN-CAM-FOV-CLIMB` — climbing is not a speed rung and §2.1 frames it at 62°
## of its own. A state answering with anything else has either hardcoded a number
## or reached for a tunable that is not a lens at all.
func _ladder() -> Array[float]:
	return [
		Tuning.camera.fov_blend,
		Tuning.camera.fov_stroll,
		Tuning.camera.fov_climb,
		Tuning.camera.fov_run,
		Tuning.camera.fov_sprint,
	]


# ----------------------------------------------------- the five speed rungs --


func test_the_speed_states_return_their_documented_rungs() -> void:
	assert_almost_eq(_fov(PawnStateId.BLEND_WALK), Tuning.camera.fov_blend, 0.001)
	assert_almost_eq(_fov(PawnStateId.IDLE), Tuning.camera.fov_stroll, 0.001)
	assert_almost_eq(_fov(PawnStateId.STROLL), Tuning.camera.fov_stroll, 0.001)
	assert_almost_eq(_fov(PawnStateId.RUN), Tuning.camera.fov_run, 0.001)
	assert_almost_eq(_fov(PawnStateId.SPRINT), Tuning.camera.fov_sprint, 0.001)


func test_climbing_the_ladder_only_ever_widens() -> void:
	# The ordering asserted through the STATES rather than through the tunables,
	# which is a different claim: invariant 21 says the numbers are monotonic,
	# this says the states are wired to them in the right order. A stroll returning
	# the run rung would satisfy the invariant and still be wrong.
	var rungs: Array[StringName] = [
		PawnStateId.BLEND_WALK,
		PawnStateId.STROLL,
		PawnStateId.RUN,
		PawnStateId.SPRINT,
	]
	for i: int in range(rungs.size() - 1):
		assert_lt(
			_fov(rungs[i]),
			_fov(rungs[i + 1]),
			"%s is not narrower than %s" % [rungs[i], rungs[i + 1]]
		)


func test_standing_still_is_framed_as_a_civilian_rather_than_as_stopped() -> void:
	# Idle shares Stroll's rung deliberately. Stopping is not an act the lens
	# should announce, and a distinct idle FOV would mean the camera twitched
	# every time a player paused at a corner — the exact moment they most need
	# a stable frame to read the street.
	assert_almost_eq(_fov(PawnStateId.IDLE), _fov(PawnStateId.STROLL), 0.001)


# ------------------------------------------------- the states that are not speeds --


func test_blending_gets_the_narrow_lens() -> void:
	# Not a speed, so §4.2's table does not name it — but the narrow end exists to
	# make distant faces comparable, and standing inside a group looking at people
	# is the purest instance of that act in the game. Framing a blended player at
	# stroll would hand them a WIDER view for holding still, which is the ladder
	# backwards.
	assert_almost_eq(_fov(PawnStateId.BLENDED), Tuning.camera.fov_blend, 0.001)


func test_the_committed_states_stay_on_the_ladder() -> void:
	# Vault, Climb and Drop take away movement, not the camera (US-0021). Their
	# rungs are chosen to match the speed the manoeuvre reads as, so the lens does
	# not jump at the moment the player has least control.
	for id: StringName in [PawnStateId.VAULT, PawnStateId.CLIMB, PawnStateId.DROP]:
		assert_has(_ladder(), _fov(id), "%s left the ladder" % id)


func test_killing_and_being_stunned_are_framed_neutrally() -> void:
	# The lens says ONE thing — how fast you are moving. Spending it on "you are
	# mid-kill" would be information the actor already has and the victim cannot
	# see, and every future reader would have to guess whether a wide lens meant
	# speed or violence.
	assert_almost_eq(_fov(PawnStateId.KILL_ANIM), Tuning.camera.fov_stroll, 0.001)
	assert_almost_eq(_fov(PawnStateId.STUNNED), Tuning.camera.fov_stroll, 0.001)


func test_every_registered_state_answers_from_the_ladder() -> void:
	# The whole registry, so a state added later cannot quietly introduce a sixth
	# value. `crowdscan_fov` is deliberately NOT in the set: it is a mode, not a
	# rung, and it arrives in US-0023 through a different path.
	var offenders: PackedStringArray = []
	for script: GDScript in PawnStateMachine.REGISTERED:
		var state: PawnState = script.new()
		if not _ladder().has(state.camera_fov(_ctx)):
			offenders.append("%s -> %.1f" % [state.id(), state.camera_fov(_ctx)])
	assert_eq(offenders.size(), 0, "these states are off the ladder: " + ", ".join(offenders))


func test_an_unregistered_state_gets_the_civilian_default() -> void:
	# Three states are still unimplemented. A gap in the registry must not hand
	# the player a lens that says anything at all.
	assert_almost_eq(_fov(PawnStateId.RESPAWNING), Tuning.camera.fov_stroll, 0.001)


func test_the_rig_asks_the_state_rather_than_reading_the_velocity() -> void:
	# The rule belongs to the pawn's state. A rig that derived the rung from
	# `ctx.velocity` would drift from the state table for the length of every
	# acceleration ramp, and nothing would fail.
	var rig := SourceScanner.read("res://scripts/presentation/camera/camera_rig.gd")
	assert_true(
		rig.contains("_driver.camera_fov()"), "the rig does not ask the driver for the rung"
	)
	assert_false(
		rig.contains("ctx.velocity"), "the rig is deriving the lens from speed rather than state"
	)
	var driver := SourceScanner.read("res://scripts/presentation/local_pawn_driver.gd")
	assert_true(
		driver.contains("_machine.camera_fov(ctx)"),
		"the driver does not delegate the rung to the state machine"
	)
