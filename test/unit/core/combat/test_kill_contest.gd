## **TWO PEOPLE PRESSED KILL ON THE SAME PLAYER.** US-0060, ADR-0010, TDD-04 §8.4.
##
## The window is `TUN-KILL-CONTEST-WINDOW` 0.4 s — twelve server ticks, which
## TDD-03 §1 calls "ample resolution" — and it is resolved by **server receive
## order and nothing else**. A low-ping player wins a genuine tie; that is a real
## cost, stated in ADR-0010, and it is the only ordering the server can trust.
extends GutTest

const VICTIM := 30
const FIRST := 31
const SECOND := 32

var _contest: KillContest
var _window: int


func before_each() -> void:
	_contest = KillContest.new()
	_window = Tuning.ticks(&"TUN-KILL-CONTEST-WINDOW")


func test_the_window_is_wide_enough_to_be_a_race() -> void:
	# **THE PREMISE.** A window of one tick would make every assertion below true
	# for the wrong reason — there would be no contest, only simultaneity.
	assert_gte(_window, 6, "TUN-KILL-CONTEST-WINDOW is under 6 ticks; there is no race to resolve")


func test_the_first_claim_wins_and_the_second_loses() -> void:
	assert_true(_contest.claim(VICTIM, FIRST, 100, 1), "the first initiation was refused")
	assert_false(_contest.claim(VICTIM, SECOND, 103, 2), "a later initiation stole the victim")
	assert_eq(_contest.holder_of(VICTIM), FIRST, "the wrong killer holds the claim")


func test_a_claim_outside_the_window_is_not_a_contest() -> void:
	# A previous, resolved attempt — the first killer was interrupted, or their
	# kill landed and the victim respawned. Not a race, and the second player must
	# not be staggered for it.
	assert_true(_contest.claim(VICTIM, FIRST, 100, 1))
	assert_true(
		_contest.claim(VICTIM, SECOND, 100 + _window, 2),
		"a claim exactly one window later was treated as a contest"
	)
	assert_eq(_contest.holder_of(VICTIM), SECOND)


func test_the_last_tick_of_the_window_still_contests() -> void:
	# The boundary from the other side. Off by one here and the window is eleven
	# ticks rather than twelve, which nothing else in the game would report.
	assert_true(_contest.claim(VICTIM, FIRST, 100, 1))
	assert_false(
		_contest.claim(VICTIM, SECOND, 100 + _window - 1, 2),
		"the final tick of the contest window did not contest"
	)


func test_a_same_tick_tie_is_broken_by_arrival_order() -> void:
	# **NOT BY PEER ID AND NOT BY A COIN.** Iterating `ctx.pawns` is join order,
	# which would hand the earliest-joined player every tie for the whole match; a
	# seeded coin would make the most decisive moment in the game random. The
	# ordinal is stamped in `MatchDirector.enqueue_input`, where arrival happens.
	assert_true(_contest.claim(VICTIM, SECOND, 100, 7), "the first arrival was refused")
	assert_false(_contest.claim(VICTIM, FIRST, 100, 9), "a later arrival won a same-tick tie")
	assert_eq(_contest.holder_of(VICTIM), SECOND, "the later packet took the kill")


func test_the_higher_peer_id_can_win() -> void:
	# The counterfactual for the test above. A tie-break that had quietly become
	# "lowest peer id" would satisfy it, because 31 < 32 and the arrival order
	# happened to agree.
	assert_true(_contest.claim(VICTIM, SECOND, 100, 4))
	assert_eq(
		_contest.holder_of(VICTIM),
		SECOND,
		"the higher peer id lost a race it arrived first in — the tie-break is not arrival order"
	)


func test_the_same_killer_re_pressing_is_not_a_contest_with_themselves() -> void:
	assert_true(_contest.claim(VICTIM, FIRST, 100, 1))
	assert_true(
		_contest.claim(VICTIM, FIRST, 102, 3),
		"a killer contested their own claim and would have staggered themselves"
	)


func test_two_victims_are_two_independent_races() -> void:
	assert_true(_contest.claim(VICTIM, FIRST, 100, 1))
	assert_true(
		_contest.claim(VICTIM + 1, SECOND, 100, 2), "a claim on one victim locked out another"
	)
	assert_eq(_contest.count(), 2)


func test_a_departing_player_leaves_no_lock_behind() -> void:
	# ENet reuses peer ids, so a claim left behind is inherited: the next joiner
	# arrives already contested, or already holding a kill on somebody. US-0037's
	# lesson, applied before it can bite.
	_contest.claim(VICTIM, FIRST, 100, 1)
	_contest.claim(VICTIM + 1, FIRST, 100, 2)
	_contest.forget(FIRST)
	assert_eq(_contest.count(), 0, "a departed killer kept his claims")

	_contest.claim(VICTIM, FIRST, 100, 3)
	_contest.forget(VICTIM)
	assert_eq(_contest.holder_of(VICTIM), ContractCycle.NOBODY, "a departed victim stayed claimed")


func test_nothing_here_can_read_a_client_supplied_number() -> void:
	# **THE STRUCTURAL HALF.** `claim()` takes a server tick and a server-stamped
	# ordinal, and there is no third argument through which a client clock could
	# arrive. `InputCommand` no longer carries one at all — the two bytes that were
	# `client_tick` became `acked_tick` in US-0031 — and the guard that keeps combat
	# code away from that field is `test_no_client_time_in_kill.gd`.
	var code := SourceScanner.code_lines("res://scripts/core/combat/kill_contest.gd")
	for row: Array in code:
		var line := String(row[1])
		assert_false(line.contains("acked_tick"), "KillContest reads a client-supplied number")
		assert_false(line.contains("InputCommand"), "KillContest can see a client's own message")
