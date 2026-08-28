## **`SCORE-FOCUS`'s LINE-OF-SIGHT STREAK AND ITS GRACE.** US-0065, TDD-10 §2.1.
##
## Without the grace the bonus is **unearnable in a crowd** — which is exactly
## where GDD-07 §3 says the hardest perceptual skill in the game should be earned.
## The grace *preserves* the streak rather than pausing it: a tick spent behind a
## passing NPC still counts toward the window.
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


func test_the_grace_is_a_real_window() -> void:
	assert_gt(_grace, 1, "TUN-SCORE-FOCUS-BREAK-GRACE is under two ticks")


func test_an_unbroken_watch_accumulates() -> void:
	for _i: int in 10:
		_w.sample_focus(PEER, true, _grace)
	assert_eq(_w.focus_ticks(PEER), 10)


func test_the_grace_preserves_the_streak_rather_than_pausing_it() -> void:
	# TDD-10 §2.1: a tick spent behind a passing NPC **still counts** toward the
	# window. Pausing instead would make the bonus take longer in a crowd, which is
	# the same defect one step smaller.
	for _i: int in 10:
		_w.sample_focus(PEER, true, _grace)
	for _i: int in _grace:
		_w.sample_focus(PEER, false, _grace)
	assert_eq(
		_w.focus_ticks(PEER), 10 + _grace, "the grace paused the streak instead of keeping it"
	)


func test_a_lapse_longer_than_the_grace_resets_it() -> void:
	for _i: int in 10:
		_w.sample_focus(PEER, true, _grace)
	for _i: int in _grace + 1:
		_w.sample_focus(PEER, false, _grace)
	assert_eq(_w.focus_ticks(PEER), 0, "a lapse past the grace did not reset the streak")


func test_the_grace_re_arms_on_every_seen_tick() -> void:
	# **OTHERWISE IT IS A BUDGET FOR THE WHOLE STREAK RATHER THAN FOR ONE LAPSE**,
	# and Focus would be unearnable in a crowd after the second NPC walks past —
	# which is precisely where GDD-07 §3 says it should be earned.
	#
	# **THE FIRST SIGHTING IS WHAT ARMS IT**, which my first version of this test
	# forgot: it opened with a lapse, against a grace that no sighting had set, and
	# read 27 where it expected 39. The code was right and the arithmetic was mine.
	_w.sample_focus(PEER, true, _grace)
	for _i: int in 3:
		for _j: int in _grace:
			_w.sample_focus(PEER, false, _grace)
		assert_gt(_w.focus_ticks(PEER), 0, "a lapse inside the grace reset the streak")
		_w.sample_focus(PEER, true, _grace)
	assert_eq(_w.focus_ticks(PEER), 1 + 3 * (_grace + 1), "the grace did not re-arm")


func test_a_reassignment_breaks_the_streak() -> void:
	# A window built watching one contract says nothing about the next. Carrying it
	# across would pay Focus for attention never spent on the person who died.
	for _i: int in 10:
		_w.sample_focus(PEER, true, _grace)
	_w.break_focus(PEER)
	assert_eq(_w.focus_ticks(PEER), 0, "the streak survived a new contract")
