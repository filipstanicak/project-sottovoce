## The client's view of server time. TDD-04 §5, US-0034.
##
## Two properties carry the whole design: it **only moves forward**, and it
## **does not smooth**. Everything else is arithmetic.
extends GutTest

var _clock: RenderClock


func before_each() -> void:
	_clock = RenderClock.new()


func test_it_has_no_opinion_until_a_snapshot_arrives() -> void:
	# Callers read a negative render time as "nothing to draw yet". A clock that
	# started at zero would render the first 100 ms of every match against a
	# server timeline that had not started.
	assert_false(_clock.started())
	assert_lt(_clock.render_time(), 0.0)


func test_it_renders_the_tuned_delay_behind_the_newest_snapshot() -> void:
	_clock.observe(10.0)
	assert_almost_eq(_clock.render_time(), 10.0 - Tuning.net.interp_buffer / 1000.0, 0.0001)


func test_the_delay_is_the_tunable_and_not_a_literal() -> void:
	# `TUN-NET-INTERP-BUFFER` is 100 ms and **fixed, not adaptive** (ASM-0021):
	# remote timing that changed between sessions would confound every balance
	# judgement made against it.
	assert_almost_eq(Tuning.net.interp_buffer, 100.0, 0.001)


func test_it_keeps_running_between_snapshots() -> void:
	# **THE REASON REMOTE PAWNS MOVE AT ALL** rather than stepping 30 times a
	# second. Between snapshots this is the only thing advancing.
	_clock.observe(10.0)
	var before := _clock.render_time()
	_clock.advance(1.0 / 60.0)
	assert_gt(_clock.render_time(), before, "the clock stopped between snapshots")


func test_it_does_not_run_before_the_first_snapshot() -> void:
	_clock.advance(1.0)
	assert_false(_clock.started(), "the clock started itself")


func test_a_late_snapshot_never_winds_it_back() -> void:
	# **REMOTE PAWNS WOULD JUMP BACKWARDS**, which reads as a rubber-band on
	# somebody else's screen and is indistinguishable from a real one. Late is
	# late; the interpolator holds.
	_clock.observe(10.0)
	_clock.advance(0.5)
	var ahead := _clock.render_time()
	_clock.observe(9.0)
	assert_almost_eq(_clock.render_time(), ahead, 0.0001, "a late snapshot rewound the clock")


func test_a_snapshot_from_the_future_pulls_it_forward() -> void:
	# The ordinary case: the server is always ahead, and the clock follows.
	_clock.observe(10.0)
	_clock.observe(11.0)
	assert_almost_eq(_clock.render_time(), 11.0 - Tuning.net.interp_buffer / 1000.0, 0.0001)


func test_it_does_not_ease_toward_the_server() -> void:
	# A clock that eased would make the interpolation delay drift, and a drifting
	# delay is an adaptive buffer by accident — which ASM-0021 refuses.
	_clock.observe(100.0)
	assert_almost_eq(_clock.render_time(), 100.0 - Tuning.net.interp_buffer / 1000.0, 0.0001)


func test_resetting_forgets_the_match() -> void:
	_clock.observe(10.0)
	_clock.reset()
	assert_false(_clock.started())
