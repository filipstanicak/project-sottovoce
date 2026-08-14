## **THE HARDEST THING IN THIS STORY TO TEST IS AN ABSENCE.** GDD-02 §4.3,
## US-0023.
##
## Crowd-scan is the game's aim-down-sights and it grants **no mechanical
## advantage**: no reveal, no highlight, no tag. §4.3 calls it the single
## clearest statement of what kind of game this is. What it grants is a narrower
## lens and a slower pan — the advantage is entirely in the player's own
## perception, which is not something a test can reach.
##
## So the assertions below are the negative shape of that. Two identical pawns
## are stepped with identical input differing only in the scan bit, and
## everything that comes out must match except the one thing scanning is
## *supposed* to cost: speed. A feature that quietly started granting something
## would show up here as a field that stopped matching.
extends GutTest

const DT := 1.0 / 60.0

var _machine: PawnStateMachine


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())


func after_each() -> void:
	_machine.free()


func _ctx(state: StringName) -> PawnContext:
	var ctx := PawnContext.new()
	ctx.state_id = state
	ctx.position = Vector3(20.0, 0.0, 20.0)
	ctx.grounded = true
	return ctx


## Walking forward, plus whatever holds the pawn on the rung it starts on.
##
## The bits are set from the rung the pawn starts on, so nothing climbs the
## ladder mid-test — an escalation would make every assertion below about a state
## the pawn was no longer in.
func _walk_command(scanning: bool, hold: StringName = &"") -> InputCommand:
	var command := InputCommand.empty(1)
	command.move = Vector2(0.0, 1.0)
	command.scan = scanning
	command.run = hold == PawnStateId.RUN or hold == PawnStateId.SPRINT
	command.sprint = hold == PawnStateId.SPRINT
	return command


## Run one pawn for `frames` steps and hand back what it became.
func _drive(state: StringName, scanning: bool, frames: int) -> PawnContext:
	var ctx := _ctx(state)
	var command := _walk_command(scanning, state)
	for _i: int in frames:
		ctx.state_timer_ticks += 1
		_machine.step(ctx, command, DT)
	return ctx


# ------------------------------------------------------------- what it costs --


func test_it_caps_the_speed_at_a_civilian_pace() -> void:
	# The one thing scanning changes. You cannot read the crowd while crossing it
	# at speed — 01_vision.md §6.1's loop tension, made real.
	var scanning := _drive(PawnStateId.STROLL, true, 60)
	assert_almost_eq(
		scanning.velocity.length(), Tuning.movement.blend_walk, 0.01, "the scan did not cap speed"
	)


func test_the_cap_binds_from_every_rung_of_the_ladder() -> void:
	# Including sprint, which is 4.4x the cap. A scan that only capped the slow
	# states would let a sprinting player read the crowd, which is the whole
	# thing the tension is built on.
	for state: StringName in [PawnStateId.STROLL, PawnStateId.RUN, PawnStateId.SPRINT]:
		var ctx := _drive(state, true, 90)
		assert_eq(ctx.state_id, state, "%s did not hold its rung for the test" % state)
		assert_lte(
			ctx.velocity.length(),
			Tuning.movement.blend_walk + 0.01,
			"%s outran the scan cap at %.2f m/s" % [state, ctx.velocity.length()]
		)


# ------------------------------------------------------- what it must not grant --


func test_it_caps_the_speed_and_never_the_state() -> void:
	# **THE TRAP THIS STORY IS BUILT AROUND.** Routing the cap through the slow
	# path would drop a scanning player into BlendWalk — whose suspicion DECAYS.
	# A button that launders suspicion is a mechanical advantage, and a large one.
	var scanning := _drive(PawnStateId.RUN, true, 60)
	assert_eq(scanning.state_id, PawnStateId.RUN, "scanning changed the state")


func test_it_does_not_discount_the_rung_the_player_chose() -> void:
	# Run charges TUN-SUSPICION-GAIN-RUN whether or not you are scanning. Moving
	# at a civilian's pace while paying a runner's price is the correct answer:
	# scanning is a cost, never a refund.
	var run := _machine.state_for(PawnStateId.RUN)
	var scanning := _drive(PawnStateId.RUN, true, 60)
	var plain := _drive(PawnStateId.RUN, false, 60)
	assert_eq(run.suspicion_rate(scanning), run.suspicion_rate(plain))
	assert_gt(run.suspicion_rate(scanning), 0.0, "running stopped costing anything at all")


func test_two_pawns_differing_only_in_the_scan_bit_end_up_the_same() -> void:
	# The whole context, field by field, so a future change that granted something
	# has to declare itself here. `velocity` is the documented cost, and
	# `held_buttons` is the previous frame's input echoed back for edge detection —
	# it is the PREMISE of these two trials, not a result of them, and it differs
	# by construction the moment the two commands differ in any bit at all.
	#
	# `position` is deliberately not excluded, and matches: `step()` computes a
	# velocity and the DRIVER moves the body, so covering less ground is an
	# integration-level fact. It is asserted in `test_crowd_scan.gd`, where a body
	# exists to be moved.
	var scanning := _drive(PawnStateId.STROLL, true, 45)
	var plain := _drive(PawnStateId.STROLL, false, 45)
	var differences: PackedStringArray = []
	for property: Dictionary in scanning.get_property_list():
		var name: String = property["name"]
		if name == "velocity" or name == "held_buttons":
			continue
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if typeof(scanning.get(name)) == TYPE_OBJECT:
			continue
		if scanning.get(name) != plain.get(name):
			differences.append("%s: %s vs %s" % [name, scanning.get(name), plain.get(name)])
	assert_eq(differences.size(), 0, "scanning changed more than speed: " + ", ".join(differences))


func test_slowing_down_is_still_available_while_scanning() -> void:
	# ADR-0012 admits no exceptions: slow is available from every locomotion
	# state, in one tick, never gated. A modal input that suspended it would be
	# the first exception, and it would be found by a player at the worst moment.
	var ctx := _ctx(PawnStateId.RUN)
	var command := _walk_command(true, PawnStateId.RUN)
	command.slow = true
	ctx.state_timer_ticks += 1
	assert_eq(
		_machine.state_for(PawnStateId.RUN).step(ctx, command, DT),
		PawnStateId.BLEND_WALK,
		"scanning swallowed the slow input"
	)


func test_nothing_in_the_pawn_layer_reads_the_scan_bit_except_the_speed_cap() -> void:
	# A source scan, because "grants no advantage" is a claim about code that does
	# not exist. One reference, in the one place §4.3 sanctions.
	var hits: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://scripts/pawn"):
		var source := SourceScanner.read(path)
		if source.contains("input.scan") or source.contains("InputBits.SCAN"):
			hits.append(path)
	assert_eq(
		hits.size(),
		2,
		(
			"expected the cap in locomotion_state.gd and the accessor in "
			+ "input_command.gd, found: "
			+ ", ".join(hits)
		)
	)
