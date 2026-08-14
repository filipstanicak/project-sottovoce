## The server's clock and its order. US-0027.
##
## The rate is asserted by **counting**, over a long run, because that is the
## only way drift shows: a director that fires 29 or 31 times in a second looks
## perfect for one second and is a tick behind after a minute.
extends GutTest

const PEER := 5

var _director: MatchDirector
var _ticks: int = 0
var _substeps: Array = []


func before_each() -> void:
	_ticks = 0
	_substeps = []
	_director = MatchDirector.new()
	add_child_autofree(_director)
	_director.net_ticked.connect(func(_c: MatchContext, _d: float) -> void: _ticks += 1)
	_director.input_applied.connect(
		func(peer: int, command: InputCommand, dt: float) -> void:
			_substeps.append([peer, command.seq, dt])
	)
	_director.ctx.phase = MatchPhase.Phase.ACTIVE


## Drive the director's own clock directly. Waiting on real physics frames would
## make a 10 000-frame assertion take three minutes.
func _run_frames(count: int) -> void:
	for _i: int in count:
		_director._physics_process(1.0 / Tuning.net.client_input_rate)


func test_the_net_tick_fires_every_second_physics_frame() -> void:
	_run_frames(60)
	assert_eq(_ticks, 30, "60 physics frames did not produce exactly 30 net ticks")


func test_it_does_not_drift_over_ten_thousand_frames() -> void:
	# **THE ASSERTION THE WHOLE FILE IS FOR.** An accumulator that fired when
	# `delta` passed 33.3 ms passes the test above and fails this one, because
	# float error is invisible until it has been added up five thousand times.
	_run_frames(10000)
	assert_eq(_ticks, 5000, "the net tick drifted over 10 000 frames")


func test_the_tick_counter_is_monotonic_and_matches() -> void:
	_run_frames(200)
	assert_eq(_director.ctx.tick, 100, "ctx.tick disagrees with the number of ticks fired")


func test_the_clock_advances_even_when_nothing_simulates() -> void:
	# A monotonic tick that stopped in the lobby would restart every match at a
	# different number, and every duration measured in ticks would mean something
	# different depending on how long the lobby sat there.
	_director.ctx.phase = MatchPhase.Phase.LOBBY
	_run_frames(60)
	assert_eq(_director.ctx.tick, 30, "the clock stopped outside play")


func test_elapsed_time_is_derived_from_the_tick() -> void:
	# Never measured. A clock read from `Time` drifts from the tick count under
	# load, and then "how long is left" has two answers — one the players see and
	# one the scoring uses.
	_run_frames(600)
	assert_almost_eq(_director.ctx.elapsed(), 10.0, 0.001, "600 frames were not 10 seconds")


# ------------------------------------------------------------- pawn substeps --


func test_each_queued_command_produces_exactly_one_substep() -> void:
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_director.enqueue_input(PEER, InputCommand.empty(2))
	_run_frames(2)
	assert_eq(_substeps.size(), 2, "two commands did not produce two substeps")
	assert_eq(_substeps[0][1], 1, "the commands were applied out of order")
	assert_eq(_substeps[1][1], 2)


func test_a_substep_runs_at_the_input_rate_not_the_tick_rate() -> void:
	# **THE REASON THE SUBSTEP EXISTS.** The client integrated two steps of
	# 1/60 with a decision between them. One step of 1/30 lands somewhere else on
	# every curve that is not linear, and at TUN-SPEED-ACCEL 18 m/s² the
	# divergence is immediate and permanent.
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_run_frames(2)
	assert_almost_eq(_substeps[0][2], 1.0 / Tuning.net.client_input_rate, 0.0001)
	assert_ne(_substeps[0][2], 1.0 / Tuning.net.server_tick, "the pawn was stepped at the net rate")


func test_a_tick_with_no_input_produces_no_substep() -> void:
	# A pawn that stepped on an empty queue would be integrating a stale command,
	# which is a client's last input repeating forever after they stop sending.
	_run_frames(20)
	assert_eq(_substeps.size(), 0, "a substep ran with nothing queued")


func test_the_queue_drops_the_oldest_rather_than_growing() -> void:
	# A client that stalls and dumps its backlog must not buy a hundred substeps
	# of catch-up in one tick: that is a hitch for everyone else and a speed
	# advantage for the player who lagged.
	var cap: int = Tuning.net.input_buffer_size
	for i: int in cap + 10:
		_director.enqueue_input(PEER, InputCommand.empty(i))
	assert_eq(_director.queued_for(PEER), cap, "the queue grew past the buffer size")
	_run_frames(2)
	assert_eq(_substeps[0][1], 10, "the queue dropped the newest instead of the oldest")


func test_nothing_simulates_outside_play() -> void:
	_director.ctx.phase = MatchPhase.Phase.LOBBY
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_run_frames(20)
	assert_eq(_substeps.size(), 0, "input was applied in the lobby")


func test_a_departed_peer_leaves_nothing_queued() -> void:
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_director.forget(PEER)
	_run_frames(2)
	assert_eq(_substeps.size(), 0, "a peer that left still had input applied")
