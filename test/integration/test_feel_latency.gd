## **INPUT-TO-RESPONSE LATENCY, MEASURED.** GDD-02 §5, US-0024.
##
## The harness the feel budget has been asserted by prose since M0. It presses a
## real key on the real client and counts physics frames until the pawn actually
## does something, then converts at `TUN-NET-CLIENT-INPUT-RATE`.
##
## **IT MEASURES THREE STAGES OF FIVE AND SAYS SO.** `FeelChain` declares the
## chain — sample, simulate, apply, animate, present — and the last two are
## blocked: there are no animation clips, and headless CI has no display. So the
## numbers below are a *lower bound* on input-to-visible-response, and US-0024's
## criteria 1 and 2 stay unticked. A harness that printed "17 ms, within budget"
## while skipping the stage the budget is named after would be worse than no
## harness, because the number reads as authoritative.
##
## What it does prove is real and had never been checked: **one tick to slow
## down, two to start moving from rest.** The second one is `IdleState.step()`
## integrating toward its own target of zero before handing over to Stroll — so
## the asymmetry ADR-0012 describes in prose ("the defensive option is cheap; the
## aggressive one is not") turns out to be visible at tick resolution. 16.7 ms
## against 33.3, both inside an 80 ms budget.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Enough for the press to reach the pawn many times over. A budget failure shows
## up as a count of 5+; this ceiling only stops a hang from looping forever.
const PATIENCE := 60

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


func _settle(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


## Press `action` and count SIMULATION STEPS until `responded` returns true.
##
## Counted on `pawn_stepped`, the driver's own signal, rather than on
## `SceneTree.physics_frame`. The signal fires after `step()` and `_apply_motion`
## have both run, so a step that reports no response really had none — where a
## tree-frame count would straddle the driver and leave the reading depending on
## node order.
func _ticks_until(action: StringName, responded: Callable) -> int:
	Input.action_press(action)
	for tick: int in range(1, PATIENCE + 1):
		await _driver.pawn_stepped
		if responded.call():
			return tick
	return -1


func _report(what: String, ticks: int) -> float:
	var ms := FeelChain.ms_for_ticks(ticks)
	gut.p("%s: %d tick(s) = %.1f ms — %s" % [what, ticks, ms, FeelChain.coverage_note()])
	return ms


# ------------------------------------------------------- the measured stages --


func test_a_key_press_moves_the_pawn_within_budget() -> void:
	# Sample -> simulate -> apply, end to end, from a settled standstill.
	#
	# **TWO TICKS, AND THE SECOND ONE IS ADR-0012.** `IdleState.step()` integrates
	# toward its own target of zero and *then* hands over to Stroll, so the first
	# tick of input produces a state change and no speed. Accelerating from rest
	# costs one tick more than slowing down does — which is the acceleration curve
	# the design asked for, visible at tick resolution.
	await _settle(30)
	var ticks: int = await _ticks_until(
		&"input_move_forward", func() -> bool: return _driver.ctx.velocity.length() > 0.0
	)
	assert_eq(ticks, 2, "starting from rest no longer takes exactly two ticks")
	var ms := _report("input -> first velocity (from rest)", ticks)
	assert_true(
		FeelChain.within_budget(ms),
		"the measured stages alone are over the %.0f ms budget" % FeelChain.budget_ms()
	)


func test_the_body_actually_moves_within_budget() -> void:
	# One stage further than the test above: through `_apply_motion` and into the
	# physics body. US-0019's vault computed a perfect arc and moved nothing, so
	# a velocity changing is not proof that anything did.
	#
	# **SETTLE FIRST.** A freshly spawned pawn slides 0.088 m on its first frame
	# resolving onto the floor, and an unsettled measurement reports that as a
	# 1-tick response to a key that had not been read yet. This harness exists to
	# produce a number worth quoting; trap 4's rule — assert the SHAPE of a
	# result, not its magnitude — applies hardest to the harness itself.
	await _settle(30)
	var start := _driver.ctx.position
	var ticks: int = await _ticks_until(
		&"input_move_forward", func() -> bool: return _driver.ctx.position.distance_to(start) > 0.0
	)
	assert_gt(ticks, 0, "the body never moved")
	assert_true(FeelChain.within_budget(_report("input -> body moved", ticks)))


# ------------------------------------------ the same numbers, over a network --


## Press `action` inside a running match and count simulation steps until
## `responded`. One `advance(1)` is one pumped wire plus one physics frame, so a
## count here is the same unit as `_ticks_until` above.
func _ticks_until_networked(
	harness: IntegrationHarness, action: StringName, responded: Callable
) -> int:
	Input.action_press(action)
	for tick: int in range(1, PATIENCE + 1):
		await harness.advance(1)
		if responded.call():
			return tick
	return -1


func test_the_response_is_the_same_with_prediction_active() -> void:
	# **US-0024'S SECOND CRITERION, AND THE HALF OF IT THAT WAS BLOCKED.** It asked
	# for the measurement "with prediction active", and prediction did not exist
	# until US-0032. It does now, so this presses the same key against a running
	# match — a real server, a real snapshot stream, reconciliation live, and a
	# TYPICAL connection holding every packet six frames each way.
	#
	# **THE ANSWER IS THAT NOTHING CHANGES, AND THAT IS THE WHOLE POINT OF
	# PREDICTION.** The client simulates its own input immediately; the network
	# decides when it is CORRECTED, never when it responds. A number that grew
	# with latency here would mean the local pawn was waiting for the server,
	# which is the defect prediction exists to prevent.
	var harness := IntegrationHarness.new()
	harness.start(get_tree(), self, &"TYPICAL")
	harness.add_client(1)
	await harness.advance(30)

	var driver := harness.driver_for(1)
	var ticks: int = await _ticks_until_networked(
		harness, &"input_move_forward", func() -> bool: return driver.ctx.velocity.length() > 0.0
	)
	var ms := _report("input -> first velocity, prediction active (TYPICAL)", ticks)
	assert_eq(ticks, 2, "the network changed how long the local pawn takes to respond")
	assert_true(
		FeelChain.within_budget(ms),
		(
			"the measured stages are over the %.0f ms budget with prediction active"
			% (FeelChain.budget_ms())
		)
	)
	harness.tear_down()


func test_latency_does_not_change_the_response_at_any_profile() -> void:
	# The claim stated as a property rather than as one reading. If the local
	# response were waiting on the wire at all, the worst profile would show it.
	var readings: Dictionary = {}
	for profile: StringName in IntegrationHarness.PROFILES:
		var harness := IntegrationHarness.new()
		harness.start(get_tree(), self, profile)
		harness.add_client(1)
		await harness.advance(30)
		var driver := harness.driver_for(1)
		readings[profile] = await _ticks_until_networked(
			harness,
			&"input_move_forward",
			func() -> bool: return driver.ctx.velocity.length() > 0.0
		)
		harness.tear_down()
		await get_tree().physics_frame

	for profile: StringName in IntegrationHarness.PROFILES:
		assert_eq(
			int(readings[profile]),
			2,
			(
				"%s answered in %d ticks — the local pawn is waiting on the wire"
				% [profile, int(readings[profile])]
			)
		)
	gut.p("input -> first velocity at every profile: %s tick(s)" % str(readings))


func test_slowing_down_costs_exactly_one_tick() -> void:
	# ADR-0012's claim, measured rather than asserted. "Instant from every state,
	# in ONE tick, never gated" is the M1 feel gate's first line, and it is the
	# one line of that gate a machine can check.
	Input.action_press(&"input_move_forward")
	Input.action_press(&"input_run")
	await _settle(40)
	assert_eq(_driver.ctx.state_id, PawnStateId.RUN, "the pawn never reached Run")

	var ticks: int = await _ticks_until(
		&"input_slow", func() -> bool: return _driver.ctx.state_id == PawnStateId.BLEND_WALK
	)
	# **THE ASYMMETRY IS THE DESIGN.** One tick down, two up — and this is the only
	# place in the project where "the defensive option is cheap; the aggressive one
	# is not" is measured rather than described.
	assert_eq(ticks, 1, "slowing down took %d ticks, not one" % ticks)
	_report("run -> blend-walk", ticks)


func test_it_responds_from_every_rung_of_the_ladder() -> void:
	# A response measured from rest is the easy case. The budget has to hold from
	# a sprint too, where the pawn is already moving and the *change* is what the
	# player is watching for.
	Input.action_press(&"input_move_forward")
	# A double-tap, because a sustained hold means Run now.
	Input.action_press(&"input_run")
	await _settle(2)
	Input.action_release(&"input_run")
	await _settle(2)
	Input.action_press(&"input_run")
	await _settle(50)
	assert_eq(_driver.ctx.state_id, PawnStateId.SPRINT, "the pawn never reached Sprint")

	var fast := _driver.ctx.velocity.length()
	var ticks: int = await _ticks_until(
		&"input_slow", func() -> bool: return _driver.ctx.velocity.length() < fast
	)
	assert_gt(ticks, 0, "a sprinting pawn did not begin slowing")
	assert_true(FeelChain.within_budget(_report("sprint -> deceleration begins", ticks)))


# ------------------------------------------------------ what is NOT measured --


func test_the_harness_reports_its_own_coverage() -> void:
	# **THE ASSERTION THAT KEEPS THE NUMBERS HONEST.** Every reading above is
	# printed with this note attached. Without it the first number in the log gets
	# quoted as input-to-animation latency, which is not what any of them are.
	var note := FeelChain.coverage_note()
	assert_string_contains(note, "NOT covered")
	assert_string_contains(note, "ANIMATE")
	assert_eq(
		FeelChain.unmeasured().size(),
		2,
		"the coverage changed — if a stage became measurable, measure it here"
	)
