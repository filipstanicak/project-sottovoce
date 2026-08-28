## **`SCORE-LONGHUNT`'s CLOCK AND `SCORE-VENDETTA`'s DEBT.** US-0065, TDD-10 §2.
##
## The hunt runs from the **later** of the contract announcement and the first
## Compass lock, because a hunt only really begins when you know who you are
## looking for. The debt is a single overwrite, which is what makes *\"and has not
## died since\"* true without a second field.
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


func test_the_hunt_runs_from_the_later_of_assignment_and_first_lock() -> void:
	# US-0065's criterion. A hunt only really begins when you know who you are
	# looking for, so an assignment you have not acted on does not accrue.
	_w.begin_hunt(PEER, 100)
	assert_eq(_w.hunt_ticks(PEER, 400), 300, "the clock did not run from the assignment")
	_w.note_lock(PEER, 250)
	assert_eq(_w.hunt_ticks(PEER, 400), 150, "the lock did not move the clock forward")


func test_an_earlier_lock_never_moves_the_clock_backwards() -> void:
	# The counterfactual: "whichever is later" is a max, not an overwrite. A lock
	# completed before the reassignment — on the previous contract — must not
	# lengthen a hunt that has not started.
	_w.begin_hunt(PEER, 300)
	_w.note_lock(PEER, 100)
	assert_eq(_w.hunt_ticks(PEER, 400), 100, "an old lock lengthened the new hunt")


func test_a_player_with_no_hunt_has_no_clock() -> void:
	assert_eq(_w.hunt_ticks(PEER, 9999), 0, "an unassigned player has been hunting since tick zero")


func test_a_death_ends_the_hunt_and_the_watch() -> void:
	_w.begin_hunt(PEER, 100)
	for _i: int in 10:
		_w.sample_focus(PEER, true, _grace)
	_w.report_death(PEER)
	assert_eq(_w.hunt_ticks(PEER, 400), 0, "a corpse is still hunting")
	assert_eq(_w.focus_ticks(PEER), 0, "a corpse is still watching")


func test_the_debt_is_owed_to_the_last_person_who_killed_you() -> void:
	_w.note_killed_by(PEER, OTHER)
	assert_true(_w.avenges(PEER, OTHER), "killing your killer is not vendetta")
	assert_false(_w.avenges(OTHER, PEER), "the debt runs both ways")
	assert_false(_w.avenges(PEER, 99), "any kill counts as revenge")


func test_dying_to_somebody_else_transfers_the_debt() -> void:
	# **"AND HAS NOT DIED SINCE", WITHOUT A SECOND FIELD.** The overwrite is the
	# rule: die to somebody else and they are the debt you are owed now.
	_w.note_killed_by(PEER, OTHER)
	_w.note_killed_by(PEER, 99)
	assert_false(_w.avenges(PEER, OTHER), "an old debt survived a newer death")
	assert_true(_w.avenges(PEER, 99))


func test_nobody_is_owed_a_debt_by_default() -> void:
	assert_false(_w.avenges(PEER, OTHER), "a player who has never died is owed revenge")
	assert_false(_w.avenges(PEER, 0), "peer zero is owed revenge by everybody")


func test_forgetting_a_peer_clears_the_debt_they_are_owed() -> void:
	# ENet reuses peer ids (US-0037). A debt left behind is a Vendetta bonus paid to
	# the next joiner for a kill they were not part of.
	_w.note_killed_by(PEER, OTHER)
	_w.forget(OTHER)
	assert_false(_w.avenges(PEER, OTHER), "a departed player still owes a debt")
