## **THE PORTRAIT IS EARNED, PERMANENT, AND RESET ON REASSIGNMENT.** US-0058,
## ASM-0030, GDD-03 §8.5.
##
## The HUD's contract portrait is a featureless unknown when a contract is
## assigned. Completing a lock fills it **for the duration of that contract**.
##
## **A PORTRAIT POPULATED ON ASSIGNMENT WOULD GUT THE CROWD.** Knowing the
## persona collapses the candidate set from 60–90 figures to 8–13, and GDD-03 §8.5
## makes it the single most valuable piece of information in the game. Earning it
## satisfies both halves: the search is preserved by default, and the hardest skill
## in the game gets a payoff that outlasts the 1.5 s reveal.
##
## **THE 1.5 s REVEAL ALONE WOULD NOT PAY FOR THE 1.6 s LOCK.** That is ASM-0030's
## own argument for why the portrait exists, and it is why "permanent" is a
## criterion rather than a nicety.
extends GutTest

const HUNTER := 41
const FIRST := 42
const SECOND := 43

const DT := 1.0 / 30.0

var _lock: CompassLock
var _t: CompassTuning


func before_each() -> void:
	_lock = CompassLock.new()
	_t = Tuning.compass


func _watch(contract: int, seconds: float, can_lock := true) -> void:
	for _step: int in int(round(seconds / DT)):
		_lock.advance(HUNTER, contract, can_lock, DT, false)


## Fill the arc and stop on the **tick the reveal lands**, so a caller can read
## the cooldown at full rather than a few ticks into it.
func _complete(contract: int) -> void:
	for _step: int in int(round((_t.lock_fill_time + 0.5) / DT)):
		if _lock.advance(HUNTER, contract, true, DT, false):
			return
	fail_test("the lock did not complete inside TUN-COMPASS-LOCK-FILL-TIME")


func test_the_portrait_is_unknown_before_any_lock() -> void:
	_watch(FIRST, 0.5)
	assert_false(_lock.portrait_revealed(HUNTER, FIRST), "the portrait was filled on assignment")


func test_completing_a_lock_fills_it() -> void:
	# `_complete` returns on the tick the reveal lands, so it asserts nothing by
	# itself — GUT counts a test with no assertions as risky, which is how this
	# omission surfaced rather than passing quietly.
	_complete(FIRST)
	assert_true(_lock.portrait_revealed(HUNTER, FIRST), "a completed lock filled no portrait")
	assert_true(_lock.revealing(HUNTER), "a completed lock granted no silhouette")
	assert_eq(_lock.fraction_of(HUNTER), 1.0, "the arc was not full on completion")


func test_it_survives_the_reveal_ending() -> void:
	# **THE WHOLE POINT.** The silhouette lasts `TUN-COMPASS-REVEAL-DURATION` 1.5 s;
	# the portrait does not go with it, or the lock would be worth 1.5 s of
	# advantage for 1.6 s of standing still.
	_complete(FIRST)
	_watch(FIRST, _t.reveal_duration + 1.0, false)
	assert_false(_lock.revealing(HUNTER), "the silhouette outlasted TUN-COMPASS-REVEAL-DURATION")
	assert_true(_lock.portrait_revealed(HUNTER, FIRST), "the portrait went out with the reveal")


func test_it_survives_the_contract_walking_away() -> void:
	_complete(FIRST)
	_watch(FIRST, 30.0, false)
	assert_eq(_lock.fraction_of(HUNTER), 0.0, "the arc did not drain — this proves nothing")
	assert_true(_lock.portrait_revealed(HUNTER, FIRST), "the portrait was lost with the arc")


func test_it_resets_to_unknown_on_reassignment() -> void:
	# ASM-0030's second half, and the reason the record stores *which* contract
	# rather than a boolean: the reset is a comparison, not an event somebody has
	# to remember to send.
	_complete(FIRST)
	_watch(SECOND, 0.2)
	assert_false(_lock.portrait_revealed(HUNTER, SECOND), "a new contract inherited the portrait")


func test_the_old_portrait_does_not_come_back_with_the_old_contract() -> void:
	# **A CONTRACT CYCLE CAN HAND YOU THE SAME PLAYER TWICE.** `ContractCycle`'s
	# anti-repeat rule makes it unlikely rather than impossible, and a portrait that
	# survived the gap would be an identification the hunter did not earn this time.
	_complete(FIRST)
	_watch(SECOND, 0.2)
	_watch(FIRST, 0.2)
	assert_false(_lock.portrait_revealed(HUNTER, FIRST), "a stale portrait was restored")


func test_reassignment_also_empties_the_arc() -> void:
	# Progress toward identifying somebody the hunter has just stopped hunting is
	# progress they should not keep. Half-filled on the old contract, empty on the new.
	_watch(FIRST, _t.lock_fill_time * 0.5)
	assert_gt(_lock.fraction_of(HUNTER), 0.3, "the premise failed")
	_watch(SECOND, DT)
	assert_lt(_lock.fraction_of(HUNTER), 0.1, "a half-filled arc carried over to a new contract")


func test_a_hunter_with_no_contract_has_no_portrait() -> void:
	_complete(FIRST)
	assert_false(
		_lock.portrait_revealed(HUNTER, ContractCycle.NOBODY),
		"a hunter between contracts still had a portrait"
	)


func test_the_reveal_cooldown_stops_chain_locking() -> void:
	# Without it a hunter with a clear view re-locks every 1.6 s and keeps their
	# target permanently outlined, which turns the Compass from a search tool into
	# a tracker. GDD-03 §8.4.
	_complete(FIRST)
	var cooldown := _lock.reveal_cooldown_ticks(HUNTER)
	assert_gt(cooldown, 0, "no cooldown was armed")
	assert_almost_eq(
		float(cooldown) / Tuning.net.server_tick,
		_t.reveal_cooldown,
		0.05,
		"the cooldown is not TUN-COMPASS-REVEAL-COOLDOWN"
	)
	# Holding the view keeps the arc full and grants nothing more until it lapses.
	_watch(FIRST, _t.reveal_cooldown * 0.5)
	assert_eq(_lock.fraction_of(HUNTER), 1.0, "a held view emptied the arc")
	assert_gt(_lock.reveal_cooldown_ticks(HUNTER), 0, "the cooldown expired early")


func test_a_second_reveal_is_granted_once_the_cooldown_lapses() -> void:
	# The counterfactual: a cooldown that never expired would satisfy the test
	# above and make the lock a once-per-contract event.
	_complete(FIRST)
	_watch(FIRST, _t.reveal_cooldown + 0.2)
	assert_true(_lock.revealing(HUNTER), "no second reveal after the cooldown lapsed")
