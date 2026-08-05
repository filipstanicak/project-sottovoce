## **SPRINT MUST NEVER OPEN BY ACCIDENT.** GDD-02 §1.5.
##
## Sprinting reaches Noticed in 1.2 s and Exposed in 2.8 s. It is a three-second
## suspicion budget, not a movement mode — and the failure that follows only
## feels fair if the spend was a choice the player made. A single tap must
## therefore do nothing at all, which is the assertion this file exists for.
##
## The friction is the only intentional friction in the input scheme. If hunters
## find sprint frustrating, the answer is a more reliable *Anonymous approach*,
## never a softer gate here (CLAUDE.md never-do #13's sibling reasoning).
extends GutTest

var _gate: SprintGate


func before_each() -> void:
	_gate = SprintGate.new()


func _hold_for(ticks: int) -> bool:
	var open := false
	for _i: int in ticks:
		open = _gate.update(true)
	return open


func _release_for(ticks: int) -> void:
	for _i: int in ticks:
		_gate.update(false)


func test_a_single_tap_does_nothing() -> void:
	assert_false(_gate.update(true), "one press opened the sprint gate")
	_gate.update(false)
	assert_false(_gate.is_open(), "the gate stayed open after a lone tap")


func test_holding_briefly_does_nothing() -> void:
	var short := Tuning.step_ticks(&"TUN-SPEED-SPRINT-HOLD") - 1
	assert_false(_hold_for(short), "the gate opened one tick early")


func test_a_sustained_hold_opens_it_exactly_at_the_tunable() -> void:
	assert_true(
		_hold_for(Tuning.step_ticks(&"TUN-SPEED-SPRINT-HOLD")),
		"holding past TUN-SPEED-SPRINT-HOLD did not reach sprint"
	)


func test_a_double_tap_inside_the_window_opens_it_immediately() -> void:
	# The whole point of offering a double-tap: a player who has decided to sprint
	# should not also have to wait 0.4 s for the decision to register.
	_gate.update(true)
	_release_for(Tuning.step_ticks(&"TUN-SPEED-SPRINT-DOUBLETAP") - 1)
	assert_true(_gate.update(true), "the second tap did not open the gate")


func test_a_double_tap_outside_the_window_does_not() -> void:
	_gate.update(true)
	_release_for(Tuning.step_ticks(&"TUN-SPEED-SPRINT-DOUBLETAP") + 2)
	assert_false(_gate.update(true), "a slow re-press counted as a double-tap")


func test_the_window_is_counted_in_ticks_from_the_tunable() -> void:
	var expected: int = int(round(Tuning.movement.sprint_doubletap * Tuning.net.client_input_rate))
	assert_eq(Tuning.step_ticks(&"TUN-SPEED-SPRINT-DOUBLETAP"), expected)
	assert_gt(
		Tuning.step_ticks(&"TUN-SPEED-SPRINT-DOUBLETAP"), 0, "the window collapsed to nothing"
	)


func test_it_stays_open_while_held() -> void:
	# The friction is the price of ENTERING sprint. Charging it every frame would
	# make sprint unusable rather than expensive, which is a different design.
	_hold_for(Tuning.step_ticks(&"TUN-SPEED-SPRINT-HOLD"))
	for _i: int in 120:
		assert_true(_gate.update(true), "the gate closed while the key was still down")


func test_releasing_closes_it_and_the_price_is_charged_again() -> void:
	# A press that arrives after the double-tap window has lapsed pays the full
	# price again. (A press arriving INSIDE the window is a double-tap and opens
	# it — that is the route, not a leak. See the test below.)
	_hold_for(Tuning.step_ticks(&"TUN-SPEED-SPRINT-HOLD"))
	assert_false(_gate.update(false), "releasing did not close the gate")
	_release_for(Tuning.step_ticks(&"TUN-SPEED-SPRINT-DOUBLETAP") + 2)
	assert_false(_gate.update(true), "the next press sprinted for free")


func test_a_release_starts_a_fresh_double_tap_window() -> void:
	# Release-then-press is the double-tap. It must work from a HOLD too, or the
	# two routes interfere and the input feels unpredictable.
	_hold_for(3)
	_gate.update(false)
	assert_true(_gate.update(true), "a tap after a short hold was not a double-tap")


func test_reset_discards_a_half_entered_double_tap() -> void:
	# Otherwise the first tap taken before a death completes against the first tap
	# taken after it, and the player sprints out of their own spawn point.
	_gate.update(true)
	_gate.update(false)
	_gate.reset()
	assert_false(_gate.update(true), "a pending tap survived a respawn")


func test_the_hold_route_is_slower_than_the_double_tap_route() -> void:
	# Both are deliberate; neither may be so slow it is useless under pressure.
	# If these ever cross, the double-tap becomes the strictly worse option and
	# §1.5's "two routes" is a fiction.
	assert_gt(
		Tuning.step_ticks(&"TUN-SPEED-SPRINT-HOLD"),
		Tuning.step_ticks(&"TUN-SPEED-SPRINT-DOUBLETAP"),
		"the sustained hold is no longer the slower route"
	)
