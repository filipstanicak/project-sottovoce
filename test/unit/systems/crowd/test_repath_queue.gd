## **THE STAGGER, ASKED DIRECTLY.** US-0041, TDD-08 §12 question 2.
##
## The queue is pure, so "at most three a tick" is a property a unit test can
## assert rather than something a profiler has to notice. The failure it exists
## to prevent has no error message: ninety path queries in one tick is a server
## that is merely *late*, and lateness in this game is a lost kill.
extends GutTest

const LIMIT := 3

var _queue: RepathQueue


func before_each() -> void:
	_queue = RepathQueue.new()


func test_it_never_hands_out_more_than_the_limit() -> void:
	for index: int in 90:
		_queue.request(index)
	for _tick: int in 10:
		assert_true(_queue.take(LIMIT).size() <= LIMIT, "the cap was exceeded")


func test_a_full_crowd_is_served_in_the_ticks_the_arithmetic_says() -> void:
	# 90 NPCs at 3 a tick is 30 ticks — a second at the net rate, and the number
	# the tunable's rationale claims. Asserting the count rather than "eventually"
	# is what makes the claim checkable.
	for index: int in 90:
		_queue.request(index)
	var ticks := 0
	while _queue.pending() > 0 and ticks < 1000:
		_queue.take(LIMIT)
		ticks += 1
	assert_eq(ticks, 30, "a 90-NPC crowd took the wrong number of ticks to serve")


func test_everybody_is_served_exactly_once() -> void:
	# **STARVATION IS THE FAILURE THAT LOOKS LIKE NOTHING.** An NPC never handed a
	# path stands still in a city for the whole match, and no counter anywhere
	# moves. FIFO is what rules it out, and this is the assertion that proves FIFO
	# rather than trusting the comment.
	for index: int in 90:
		_queue.request(index)
	var seen: Dictionary = {}
	for _tick: int in 30:
		for index: int in _queue.take(LIMIT):
			assert_false(seen.has(index), "index %d was served twice" % index)
			seen[index] = true
	assert_eq(seen.size(), 90, "somebody was never served")


func test_they_come_out_in_the_order_they_went_in() -> void:
	for index: int in [7, 3, 41, 12]:
		_queue.request(index)
	assert_eq(Array(_queue.take(4)), [7, 3, 41, 12], "the queue is not FIFO")


func test_asking_twice_while_waiting_does_not_take_two_slots() -> void:
	# A state that re-requests every tick would otherwise fill the queue with
	# itself and starve everyone behind it — which is the shape the director's
	# "no goal means ask again" rule would have had, unguarded.
	_queue.request(5)
	for _repeat: int in 20:
		_queue.request(5)
	_queue.request(6)
	assert_eq(_queue.pending(), 2, "a repeated request took extra slots")
	assert_eq(Array(_queue.take(LIMIT)), [5, 6])


func test_it_can_be_asked_again_once_served() -> void:
	_queue.request(5)
	_queue.take(LIMIT)
	assert_false(_queue.is_waiting(5))
	_queue.request(5)
	assert_true(_queue.is_waiting(5), "a served index can never ask again")


func test_a_broken_budget_stops_the_crowd_rather_than_uncapping_it() -> void:
	# The safe direction. A zero or negative limit that served *everybody* would
	# turn a misconfigured budget into the exact hitch the cap exists to prevent,
	# and it would only appear under load.
	_queue.request(1)
	assert_eq(_queue.take(0).size(), 0)
	assert_eq(_queue.take(-4).size(), 0)
	assert_eq(_queue.pending(), 1, "a bad limit consumed the queue")


func test_clear_empties_it() -> void:
	for index: int in 10:
		_queue.request(index)
	_queue.clear()
	assert_eq(_queue.pending(), 0)
	assert_false(_queue.is_waiting(3), "clear left the membership set behind")


func test_the_shipped_budget_is_the_documented_one() -> void:
	# Guards against the cap being tuned away without anybody reading TDD-08 §12.
	assert_eq(Tuning.perf.crowd_repath_per_tick, 3, "TUN-PERF-CROWD-REPATH-PER-TICK moved")
