## What `INPUT-RUN` resolves to. GDD-02 §1.5.
##
## **THE GATE IT REPLACED ANSWERED INSTANTLY AND CHANGED ITS MIND.** A held key
## opened Jog at once, Run at 0.35 s and Sprint at 0.4 s — fifty milliseconds of
## Run before it sprinted — and a double-tap ran first and sprinted second. Every
## route passed through a speed nobody asked for.
##
## So the assertions here are about *what the player never reaches*, as much as
## what they do. A gate that arrived at Run and escalated out of it a moment
## later would satisfy "a double-tap sprints" and still be the bug.
extends GutTest

var _gate: SpeedGate


func before_each() -> void:
	_gate = SpeedGate.new()


func _window() -> int:
	return Tuning.step_ticks(&"TUN-SPEED-RUN-RESOLVE")


## Hold the key for `ticks` frames and hand back every answer it gave.
func _hold(ticks: int) -> Array[int]:
	var out: Array[int] = []
	for _i: int in ticks:
		out.append(_gate.update(true))
	return out


func _release(ticks: int) -> Array[int]:
	var out: Array[int] = []
	for _i: int in ticks:
		out.append(_gate.update(false))
	return out


# --------------------------------------------------------------- holding it --


func test_the_window_is_a_real_number_of_ticks() -> void:
	# Guards every test below: at zero ticks they would all pass vacuously,
	# because Run would open on the first frame and nothing could tell the two
	# gestures apart.
	assert_gt(_window(), 1, "the resolve window is too short to resolve anything")


func test_a_press_commits_to_nothing() -> void:
	assert_eq(_gate.update(true), SpeedGate.Want.NONE, "the first frame already chose")


func test_it_stays_undecided_for_the_whole_window() -> void:
	var answers := _hold(_window())
	assert_false(SpeedGate.Want.RUN in answers, "Run opened before the window closed")
	assert_false(SpeedGate.Want.SPRINT in answers, "Sprint opened without a second tap")


func test_a_held_key_becomes_run_when_the_window_expires() -> void:
	_hold(_window())
	assert_eq(_gate.update(true), SpeedGate.Want.RUN, "a held key never resolved to Run")


func test_run_lasts_as_long_as_the_key_is_held() -> void:
	# **THE POINT OF THE WHOLE CHANGE.** The old gate turned a long hold into
	# Sprint at 0.4 s, so there was no way to simply run.
	_hold(_window() + 1)
	for answer: int in _hold(600):
		assert_eq(answer, SpeedGate.Want.RUN, "a sustained hold stopped meaning Run")


func test_releasing_ends_run() -> void:
	_hold(_window() + 1)
	assert_eq(_gate.update(false), SpeedGate.Want.NONE, "Run outlived the key")


# ------------------------------------------------------------ double-tapping --


func test_a_second_press_inside_the_window_sprints() -> void:
	_gate.update(true)
	_gate.update(false)
	assert_eq(_gate.update(true), SpeedGate.Want.SPRINT, "a double-tap did not sprint")


func test_a_double_tap_never_passes_through_run() -> void:
	# The reported symptom: "it first runs a tiny bit, till the second input is
	# registered". One window governs both halves precisely so this cannot happen.
	var answers: Array[int] = []
	answers.append(_gate.update(true))
	answers.append(_gate.update(false))
	answers.append_array(_hold(120))
	assert_false(SpeedGate.Want.RUN in answers, "the double-tap ran before it sprinted")


func test_sprint_survives_the_window_closing() -> void:
	_gate.update(true)
	_gate.update(false)
	_gate.update(true)
	for answer: int in _hold(300):
		assert_eq(answer, SpeedGate.Want.SPRINT, "sprint closed while the key was still held")


func test_a_second_press_after_the_window_is_a_new_gesture() -> void:
	_gate.update(true)
	_release(_window() + 1)
	_gate.update(true)
	var answers := _hold(_window() * 3)
	assert_false(SpeedGate.Want.SPRINT in answers, "a late second press sprinted")
	assert_true(SpeedGate.Want.RUN in answers, "a late second press never even ran")


func test_a_runner_can_double_tap_into_a_sprint() -> void:
	# Release and re-press from Run. Without this a player already running would
	# have to come to a stop to sprint, which is the opposite of what sprint is
	# for.
	_hold(_window() + 5)
	_gate.update(false)
	assert_eq(_gate.update(true), SpeedGate.Want.SPRINT, "a runner could not reach sprint")


func test_releasing_a_sprint_ends_it() -> void:
	_gate.update(true)
	_gate.update(false)
	_gate.update(true)
	assert_eq(_gate.update(false), SpeedGate.Want.NONE, "sprint outlived the key")


# -------------------------------------------------------------------- reset --


func test_reset_drops_a_half_entered_double_tap() -> void:
	# On respawn. A tap that survived a death would sprint the player out of
	# their own spawn point.
	_gate.update(true)
	_gate.update(false)
	_gate.reset()
	assert_eq(_gate.update(true), SpeedGate.Want.NONE, "half a double-tap survived the reset")


func test_reset_drops_an_open_sprint() -> void:
	_gate.update(true)
	_gate.update(false)
	_gate.update(true)
	_gate.reset()
	assert_eq(_gate.want(), SpeedGate.Want.NONE, "sprint survived the reset")


func test_never_pressing_it_wants_nothing() -> void:
	for answer: int in _release(120):
		assert_eq(answer, SpeedGate.Want.NONE, "an untouched key asked for a speed")
