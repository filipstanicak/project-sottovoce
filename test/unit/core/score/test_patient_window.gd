## **`SCORE-PATIENT`'s SPEED RING.** US-0065, TDD-10 §2.1.
##
## Sized so the bonus cannot be gamed by decelerating at the last moment: the
## **whole** window must be clean, which is why it is a ring and not a flag.
## US-0065, TDD-10 §2.1. **One of the four facts a single tick cannot answer.**
extends GutTest

const PEER := 12
const OTHER := 13

var _w: ScoreWindows
var _window: int
var _grace: int


func before_each() -> void:
	_w = ScoreWindows.new()
	_window = Tuning.ticks(&"TUN-SCORE-PATIENT-WINDOW")
	_grace = Tuning.ticks(&"TUN-SCORE-FOCUS-BREAK-GRACE")


func _walk(ticks: int, speed: float) -> void:
	for _i: int in ticks:
		_w.sample_speed(PEER, speed, _window)


func _patient() -> bool:
	return _w.peak_speed(PEER) <= Tuning.scoring.patient_speed


# ----------------------------------------------------------- the ring ---


func test_the_window_is_the_tunable_and_is_a_real_length() -> void:
	# **THE PREMISE.** At a one-tick window every assertion below is about the last
	# tick only, and the bonus would be gameable by decelerating at the last moment
	# — which is the exact thing TDD-10 §2.1 sizes the ring against.
	assert_gt(_window, 100, "TUN-SCORE-PATIENT-WINDOW is under 100 ticks")
	assert_gt(Tuning.scoring.patient_speed, Tuning.movement.stroll, "the line is below stroll")
	assert_lt(Tuning.scoring.patient_speed, Tuning.movement.run, "a running player is patient")


func test_a_whole_slow_window_is_patient() -> void:
	_walk(_window, Tuning.scoring.patient_speed - 0.1)
	assert_true(_patient(), "a whole window under the line is not patient")


func test_one_tick_over_the_line_denies_the_whole_window() -> void:
	# US-0065's criterion, word for word: *one tick above
	# `TUN-SCORE-PATIENT-SPEED` anywhere in the window denies it.*
	_walk(_window, 0.5)
	_w.sample_speed(PEER, Tuning.scoring.patient_speed + 0.01, _window)
	_walk(_window - 1, 0.5)
	assert_false(_patient(), "a sprint inside the window was forgiven")


func test_it_cannot_be_gamed_by_stopping_at_the_last_moment() -> void:
	# **THE WHOLE POINT OF A RING RATHER THAN A FLAG.** Sprint across the district,
	# stand still for a second, press kill. The window must still remember.
	_walk(_window, Tuning.movement.sprint)
	_walk(int(Tuning.net.server_tick), 0.0)
	assert_false(_patient(), "one second of standing still bought Patient back")


func test_the_ring_forgets_after_a_whole_window() -> void:
	# The counterfactual for the test above: it must be a *window* and not a life
	# sentence, or one sprint at match start would deny Patient for eight minutes.
	_walk(_window, Tuning.movement.sprint)
	_walk(_window, 0.5)
	assert_true(_patient(), "the ring never forgets, so Patient is unearnable after one sprint")


func test_a_window_that_has_not_filled_yet_is_clean_by_design() -> void:
	# **DELIBERATE, NOT A COINCIDENCE OF ZERO-INITIALISATION.** *"Never exceeded the
	# speed in the 10 s before initiation"* is true of a player who has only existed
	# for three of them, and denying the bonus for the first ten seconds of every
	# life would punish a respawn for the timing of its own death.
	_walk(3, 0.5)
	assert_true(_patient(), "a fresh life cannot earn Patient")
	assert_eq(_w.peak_speed(OTHER), 0.0, "a player who never moved has no ring at all")
