## **ONE SHOVE INTO A GROUP IS NOT FIVE STACKED CHARGES.** US-0052 criterion 4,
## TDD-07 §2.2.
##
## `TUN-SUSPICION-GAIN-NPC-BUMP` is +15 — half the way to Noticed for one
## collision. Walking into a dense pocket touches several people over a second,
## and undebounced that is +75 from one careless step: Exposed, instantly, from
## an action the design charges half a tier for.
##
## **THE COUNTERFACTUAL IS IN THIS FILE.** A debounce test that only asserts "five
## rapid bumps cost fifteen" passes on an implementation that refuses every bump
## after the first *forever*, and on one that refuses them all. Both directions
## are asserted: inside the window nothing lands, past it everything does.
extends GutTest

const PEER := 7
const OTHER := 9

var _q: SuspicionImpulses
var _t: SuspicionTuning
var _cooldown: int


func before_each() -> void:
	_q = SuspicionImpulses.new()
	_t = Tuning.suspicion
	_cooldown = Tuning.ticks(&"TUN-SUSPICION-GAIN-NPC-BUMP-COOLDOWN")


func test_the_cooldown_is_a_real_duration_and_not_a_single_tick() -> void:
	# **WITHOUT THIS THE WHOLE FILE PROVES NOTHING.** A cooldown of one tick makes
	# "inside the window" unreachable at 30 Hz, and every assertion below would be
	# true of an implementation with no rule in it.
	assert_gt(_cooldown, 1, "TUN-SUSPICION-GAIN-NPC-BUMP-COOLDOWN is not a duration in ticks")
	assert_almost_eq(
		float(_cooldown) / Tuning.net.server_tick,
		_t.gain_npc_bump_cooldown,
		0.05,
		"the tick table disagrees with the tunable it was computed from"
	)


func test_five_shoves_inside_the_window_are_one_charge() -> void:
	var landed := 0
	for tick: int in 5:
		if _q.bump(PEER, tick, _t):
			landed += 1
	assert_eq(landed, 1, "%d of five bumps in five ticks landed" % landed)
	assert_almost_eq(_q.drain(PEER), _t.gain_npc_bump, 0.001, "one bump did not cost one bump")


func test_the_same_five_shoves_spaced_out_are_five_charges() -> void:
	# **THE COUNTERFACTUAL.** The rule must be the *interval*, not "only ever one".
	var landed := 0
	for step: int in 5:
		if _q.bump(PEER, step * _cooldown, _t):
			landed += 1
	assert_eq(landed, 5, "%d of five properly spaced bumps landed" % landed)
	assert_almost_eq(
		_q.drain(PEER), _t.gain_npc_bump * 5.0, 0.001, "five bumps did not cost five bumps"
	)


func test_the_boundary_is_the_cooldown_exactly_and_not_a_tick_either_side() -> void:
	assert_true(_q.bump(PEER, 100, _t), "the first bump was refused")
	assert_false(_q.bump(PEER, 100 + _cooldown - 1, _t), "a bump landed one tick early")
	assert_true(_q.bump(PEER, 100 + _cooldown, _t), "a bump was refused at the cooldown")


func test_the_debounce_is_per_player() -> void:
	# Two players shoving the same NPC on the same tick both pay. A cooldown shared
	# across peers would make a crowded market a place where one player's mistake
	# excuses another's — free, and invisible.
	assert_true(_q.bump(PEER, 0, _t), "the first player's bump was refused")
	assert_true(_q.bump(OTHER, 0, _t), "a second player was refused for somebody else's bump")


func test_a_drain_takes_everything_once() -> void:
	_q.queue(PEER, _t.gain_loud_ability)
	_q.queue(PEER, _t.gain_failed_kill)
	assert_almost_eq(
		_q.pending(PEER),
		_t.gain_loud_ability + _t.gain_failed_kill,
		0.001,
		"two impulses in one tick did not sum"
	)
	assert_almost_eq(
		_q.drain(PEER), _t.gain_loud_ability + _t.gain_failed_kill, 0.001, "the drain lost points"
	)
	assert_eq(_q.drain(PEER), 0.0, "the queue paid twice for one tick's impulses")


func test_the_order_two_impulses_arrive_in_cannot_matter() -> void:
	# Not discipline — arithmetic. Both are positive and the clamp happens once at
	# the end, so `min(max, a + b)` is the answer whichever came first.
	var forwards := SuspicionImpulses.new()
	forwards.queue(PEER, _t.gain_witnessed_kill)
	forwards.queue(PEER, _t.gain_loud_ability)
	var backwards := SuspicionImpulses.new()
	backwards.queue(PEER, _t.gain_loud_ability)
	backwards.queue(PEER, _t.gain_witnessed_kill)
	assert_eq(forwards.drain(PEER), backwards.drain(PEER), "impulse order changed the total")


func test_a_negative_impulse_is_refused_rather_than_applied() -> void:
	# A *reduction* is decay's job or a blend's, and both have rules this queue
	# does not know — the speed ceiling, the delay, the linear crush. A negative
	# here would route around all three.
	_q.queue(PEER, -50.0)
	assert_eq(_q.pending(PEER), 0.0, "a negative impulse was queued")


func test_a_departed_peer_leaves_nothing_for_whoever_inherits_their_id() -> void:
	# **ENET REUSES PEER IDS** — US-0037. An undrained impulse or a live cooldown
	# left behind is charged to, or excuses, the next player to hold that id.
	_q.queue(PEER, _t.gain_loud_ability)
	assert_true(_q.bump(PEER, 0, _t), "the bump under test never landed")
	_q.forget(PEER)
	assert_eq(_q.pending(PEER), 0.0, "a departed peer left points owed")
	assert_true(_q.bump(PEER, 1, _t), "a rejoining peer inherited the previous one's cooldown")
