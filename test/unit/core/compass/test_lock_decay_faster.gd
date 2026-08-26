## **A BROKEN LOCK IS LOST FASTER THAN IT WAS GAINED.** US-0058, GDD-03 §8.4,
## TUNABLES §4.4.
##
## `TUN-COMPASS-LOCK-DECAY-RATE` 1.4 is the number that decides what a hunter
## does with their body. At 1.0 the arc would be a stopwatch and peeking round a
## corner repeatedly would be free; above 1.0 an interrupted view nets **negative**
## and the only way to complete a lock is to stand still and watch.
##
## **THE MECHANIC AND THE THESIS AGREE HERE, WHICH IS RARE ENOUGH TO SAY.**
## Standing still and watching is also what keeps the hunter's own suspicion at
## zero — so the game's hardest skill and its central defensive play are the same
## posture, and a hunter who plays well is invisible while doing it.
extends GutTest

const HUNTER := 31
const CONTRACT := 32

const DT := 1.0 / 30.0

var _lock: CompassLock
var _t: CompassTuning


func before_each() -> void:
	_lock = CompassLock.new()
	_t = Tuning.compass


## Run `seconds` of ticks with the view held or broken. Returns the fraction.
func _watch(seconds: float, can_lock: bool, cold_read := false) -> float:
	for _step: int in int(round(seconds / DT)):
		_lock.advance(HUNTER, CONTRACT, can_lock, DT, cold_read)
	return _lock.fraction_of(HUNTER)


func test_the_decay_rate_is_above_one() -> void:
	# **WITHOUT THIS THE WHOLE FILE PROVES NOTHING.** At exactly 1.0 the
	# interruption test below becomes "an alternating view neither gains nor
	# loses", which is a different and much weaker claim.
	assert_gt(
		_t.lock_decay_rate, 1.0, "TUN-COMPASS-LOCK-DECAY-RATE is not above 1 — peeking is free"
	)
	assert_gt(_t.lock_fill_time, 1.0, "TUN-COMPASS-LOCK-FILL-TIME is not a real commitment")


func test_an_unbroken_view_fills_the_arc_in_the_tuned_time() -> void:
	assert_lt(_watch(_t.lock_fill_time * 0.9, true), 1.0, "the arc filled early")
	_lock.clear()
	assert_almost_eq(_watch(_t.lock_fill_time, true), 1.0, 0.01, "a clear view did not complete")


func test_a_broken_view_drains_at_the_tuned_multiple_of_the_fill() -> void:
	# Fill to exactly half, then break it and measure how long half takes to go.
	_watch(_t.lock_fill_time * 0.5, true)
	var half := _lock.fraction_of(HUNTER)
	assert_almost_eq(half, 0.5, 0.02, "the premise failed — the arc is not half full")
	var drained := 0.0
	while _lock.fraction_of(HUNTER) > 0.0 and drained < 10.0:
		_lock.advance(HUNTER, CONTRACT, false, DT, false)
		drained += DT
	var expected := (_t.lock_fill_time * 0.5) / _t.lock_decay_rate
	gut.p("half an arc filled in %.2f s and drained in %.2f s" % [_t.lock_fill_time * 0.5, drained])
	assert_almost_eq(drained, expected, 0.05, "the drain is not TUN-COMPASS-LOCK-DECAY-RATE x fill")


func test_peeking_never_completes_however_long_it_goes_on() -> void:
	# **THE PROPERTY THE NUMBER EXISTS FOR.** Half a second on, half a second off,
	# for a minute. At 1.4 the net is −0.25 of the arc per second, so it does not
	# merely take longer — it never gets there at all.
	var best := 0.0
	for _cycle: int in 60:
		_watch(0.5, true)
		best = maxf(best, _lock.fraction_of(HUNTER))
		_watch(0.5, false)
	gut.p("sixty peek cycles reached %.2f of the arc at best" % best)
	assert_lt(best, 1.0, "an interrupted view completed a lock")
	assert_eq(_lock.fraction_of(HUNTER), 0.0, "the arc did not return to empty between peeks")


func test_watching_barely_more_than_half_the_time_still_never_completes() -> void:
	# **THE ASSERTION THAT ACTUALLY PINS 1.4.** The 50/50 test above passes at a
	# decay rate of 1.0 as well — net zero never reaches full either — so it proves
	# `decay >= fill` and nothing more. Falsifying against a planted 1.0 is how that
	# hole surfaced.
	#
	# At duty cycle `d` the net is `fill x (d(1 + rate) - rate)`, which crosses zero
	# at `rate / (1 + rate)` — 0.583 at 1.4, and 0.5 at 1.0. So a hunter watching
	# 55 % of the time completes a lock under the weaker rule and never does under
	# the tuned one, which is exactly the behaviour §8.4 is buying.
	var break_even: float = _t.lock_decay_rate / (1.0 + _t.lock_decay_rate)
	assert_gt(break_even, 0.55, "the tuned decay rate lets a 55 %% duty cycle succeed")
	var best := 0.0
	for _cycle: int in 60:
		_watch(0.55, true)
		best = maxf(best, _lock.fraction_of(HUNTER))
		_watch(0.45, false)
	gut.p("watching 55 %% of the time reached %.2f of the arc at best" % best)
	assert_lt(best, 1.0, "a hunter watching 55 % of the time completed a lock")


func test_committing_once_beats_peeking_for_twice_as_long() -> void:
	# The counterfactual, stated as the choice a player actually makes: 1.6 s of
	# standing still against 3.2 s of glancing.
	var committed := _watch(_t.lock_fill_time, true)
	_lock.clear()
	for _cycle: int in 4:
		_watch(_t.lock_fill_time * 0.4, true)
		_watch(_t.lock_fill_time * 0.4, false)
	assert_gt(committed, _lock.fraction_of(HUNTER), "peeking twice as long did as well as watching")


func test_cold_read_fills_faster_and_nothing_else() -> void:
	# `PASV-COLDREAD` multiplies the fill rate; it does not touch the drain, so it
	# makes committing cheaper without making peeking viable.
	_lock.clear()
	var plain := _watch(1.0, true, false)
	_lock.clear()
	var read := _watch(1.0, true, true)
	assert_almost_eq(
		read / plain, _t.cold_read_mult, 0.02, "Cold Read is not TUN-PASV-COLDREAD-MULT"
	)
	assert_lt(
		_t.lock_fill_time / _t.cold_read_mult,
		_t.lock_fill_time,
		"the passive does not shorten the fill at all"
	)


func test_the_arc_is_clamped_at_both_ends() -> void:
	assert_eq(_watch(_t.lock_fill_time * 3.0, true), 1.0, "the arc filled past full")
	assert_eq(_watch(_t.lock_fill_time * 3.0, false), 0.0, "the arc drained below empty")
