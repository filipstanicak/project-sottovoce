## **A CHASE IS LOST BY NOT LOOKING, AND THE DUTY CYCLE IS WHAT PROVES IT.**
## ADR-0014, US-0097.
##
## **THE COUNTERFACTUAL FIRST, BECAUSE THE OBVIOUS TEST CANNOT SEE THE RULE.** "A
## chase ends after `TUN-PURSUIT-DURATION` of no sight" passes just as happily
## against a bar that never refreshes at all, and against one that increments. What
## separates the three is the **duty cycle**: with refresh-to-full the answer to
## *how often must a hunter look* is **once per window, however briefly**, and that
## is a pair of assertions rather than one.
extends GutTest

var _board: PursuitBoard
var _full: int = 0


func before_each() -> void:
	_board = PursuitBoard.new()
	_full = Tuning.ticks(&"TUN-PURSUIT-DURATION")


func _drain(hunter: int, ticks: int) -> PackedInt32Array:
	var emptied := PackedInt32Array()
	for _i: int in ticks:
		for peer: int in _board.drain(PackedInt32Array([hunter])):
			emptied.append(peer)
	return emptied


func test_the_window_is_a_real_number_of_ticks() -> void:
	# **THE PREMISE.** Every assertion below is satisfied by a window of zero, and
	# by one measured in the wrong tick domain — `Tuning.ticks` is the 30 Hz net
	# tick and `step_ticks` the 60 Hz input rate, and taking the second would halve
	# a documented 10.72 s chase to 5.36 with nothing reporting it (trap 9).
	assert_gt(_full, 300, "TUN-PURSUIT-DURATION is under ten seconds of net ticks")
	assert_almost_eq(float(_full) / Tuning.net.server_tick, Tuning.contract.pursuit_duration, 0.05)


func test_a_chase_opens_full() -> void:
	_board.refresh(1, 2, _full)
	assert_true(_board.is_chasing(1))
	assert_eq(_board.prey_of(1), 2)
	assert_almost_eq(_board.fraction_of(1, _full), 1.0, 0.001)


func test_it_empties_after_the_whole_window_of_no_sight() -> void:
	_board.refresh(1, 2, _full)
	assert_eq(_drain(1, _full - 1).size(), 0, "the chase ended early")
	assert_eq(_drain(1, 1), PackedInt32Array([1]), "the chase outlived its window")


func test_a_hunter_who_looks_once_per_window_never_loses_it() -> void:
	# **HALF THE RULE.** Refresh-to-full means *any* sight inside the window is
	# enough, so a hunter who glimpses their prey every `window - 1` ticks holds the
	# chase open indefinitely. Ten cycles is 107 seconds — longer than the reference
	# hunt this is priced against.
	_board.refresh(1, 2, _full)
	for _cycle: int in 10:
		assert_eq(_drain(1, _full - 1).size(), 0, "a hunter who kept looking lost the chase")
		_board.refresh(1, 2, _full)
	assert_true(_board.is_chasing(1))


func test_a_hunter_who_looks_slower_than_the_window_loses_it_every_time() -> void:
	# **THE OTHER HALF, AND IT IS THE ONE THAT GOES RED AGAINST AN INCREMENTING
	# BAR.** With increments, a hunter one tick past the window would still be
	# holding a chase built from every earlier glimpse.
	for _cycle: int in 3:
		_board.refresh(1, 2, _full)
		assert_eq(_drain(1, _full), PackedInt32Array([1]), "a chase survived a full window")
		_board.escaped(1)
	assert_eq(_board.escapes, 3)


func test_a_refresh_does_not_stack() -> void:
	# The direct statement of the same thing: two refreshes are worth one window,
	# not two. An incrementing board passes every test above except this one.
	_board.refresh(1, 2, _full)
	_drain(1, 10)
	_board.refresh(1, 2, _full)
	_board.refresh(1, 2, _full)
	assert_eq(_board.ticks_left(1), _full, "a second refresh added to the bar")


func test_a_chase_is_keyed_on_the_hunter_and_a_new_prey_restarts_it() -> void:
	# A repair hands the hunter somebody else. Keyed on the pair, the old chase
	# would linger against a prey they no longer hold — and its timer would empty
	# and take away a contract they were never careless about.
	_board.refresh(1, 2, _full)
	_drain(1, 20)
	_board.refresh(1, 3, _full)
	assert_eq(_board.prey_of(1), 3)
	assert_eq(_board.ticks_left(1), _full, "the new chase inherited the old one's drain")


func test_the_reverse_lookup_finds_the_hunter() -> void:
	# The prey's own HUD bar comes from this: they are told a bar is draining,
	# never whose it is.
	_board.refresh(7, 8, _full)
	assert_eq(_board.hunter_of(8), 7)
	assert_eq(_board.hunter_of(9), ContractCycle.NOBODY)


func test_closing_is_not_escaping() -> void:
	# A kill, a death or a disconnect ends a chase without anybody having escaped.
	# One counter, two ways to end, and only one of them pays.
	_board.refresh(1, 2, _full)
	_board.close(1)
	assert_false(_board.is_chasing(1))
	assert_eq(_board.escapes, 0, "a death was counted as an escape")


func test_a_blend_watched_by_the_hunter_does_not_conceal() -> void:
	# GDD-03 §9.2's own rule applied to a new consumer: the crowd hides you by
	# being confusing, never by being solid. A hunter who watched you step into the
	# pocket can still pick you out of it.
	_board.refresh(1, 2, _full)
	assert_false(_board.watched_the_blend(1), "a fresh chase starts already watching")
	_board.note_blend_began(1, true)
	assert_true(_board.watched_the_blend(1))


func test_the_flag_clears_the_moment_sight_breaks() -> void:
	# **THE HALF THAT MAKES THE CLAUSE A MEMORY OF ONE MOMENT** rather than a
	# permanent property of the blend. Break the corner and the pocket closes over
	# you again.
	_board.refresh(1, 2, _full)
	_board.note_blend_began(1, true)
	_board.note_sight_broken(1)
	assert_false(_board.watched_the_blend(1), "the hunter still sees a blend they lost sight of")


func test_draining_an_unknown_hunter_is_silent() -> void:
	assert_eq(_board.drain(PackedInt32Array([99])).size(), 0)
	assert_eq(_board.fraction_of(99, _full), 0.0)
