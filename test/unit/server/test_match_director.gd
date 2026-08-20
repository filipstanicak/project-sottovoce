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


## Give the director a pawn to substep for, without a pawn. The repeat rule
## walks `ctx.pawns`, because a peer with a pawn and an EMPTY queue is exactly
## the case it exists for — and that peer has no queue entry to be found by.
func _give_a_pawn() -> void:
	_director.ctx.pawns[PEER] = self


## **A STALLED PAWN PRODUCES A POSITION THE CLIENT CANNOT HAVE PREDICTED.** The
## client kept walking; a server that waited did not. Every dropped packet would
## then guarantee a reconciliation, and a player on a lossy connection would
## stutter continuously against a server that was merely being careful. US-0028.
##
## **THIS TEST USED TO ASSERT A WIDER RULE THAN THE ONE US-0028 ARGUED FOR**, and
## the wider rule was the defect. It fed *one* command and demanded two substeps —
## treating "fewer than a full tick arrived" as starvation. Arrival is bursty, so
## that is the ordinary case: the second command is in flight, lands next tick, and
## gets applied **on top of** the repeat that already stood in for it. Five steps
## for four commands, integrating a direction the client never predicted.
##
## Starvation is when **nothing** arrives, which is what this asserts now.
func test_a_tick_with_no_input_at_all_repeats_rather_than_stalling() -> void:
	_give_a_pawn()
	_director.enqueue_input(PEER, InputCommand.empty(7))
	_run_frames(2)
	assert_eq(_substeps.size(), 1, "the one command that arrived was not applied once")

	_substeps = []
	_run_frames(2)
	assert_eq(
		_substeps.size(),
		2,
		"a tick with no input at all did not fill its substeps, so the pawn stalled"
	)
	assert_eq(_substeps[0][1], 7, "the repeat forgot what the peer was doing")


## **AND A SHORT TICK IS LEFT SHORT**, which is the other half of the same rule.
## The command that did not arrive in time is not lost, it is late; standing in for
## it is what makes the client pay for it twice.
func test_a_short_tick_is_not_padded_because_the_rest_is_merely_late() -> void:
	_give_a_pawn()
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_run_frames(2)
	assert_eq(_substeps.size(), 1, "a short tick was padded with a stale repeat")


func test_a_full_tick_of_input_is_not_padded() -> void:
	_give_a_pawn()
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_director.enqueue_input(PEER, InputCommand.empty(2))
	_run_frames(2)
	assert_eq(_substeps.size(), 2, "a full tick was padded with a repeat")


func test_a_pawn_that_has_never_had_input_is_not_stepped() -> void:
	# There is no intent to extend, and a pawn that has not yet moved must not
	# start. `InputCommand.empty()` is not "the player is standing still" — it is
	# "we have never heard from them".
	_give_a_pawn()
	_run_frames(20)
	assert_eq(_substeps.size(), 0, "a silent peer was stepped anyway")


func test_a_departed_peer_leaves_nothing_queued() -> void:
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_director.forget(PEER)
	_run_frames(2)
	assert_eq(_substeps.size(), 0, "a peer that left still had input applied")


## **A LATE COMMAND MUST NOT BE PAID FOR TWICE.** US-0028's repeat, and the defect
## an owner felt at the controls.
##
## The client sends at `TUN-NET-CLIENT-INPUT-RATE` and the server ticks at
## `TUN-NET-SNAPSHOT-RATE`, so **exactly two commands exist per tick** — but they do
## not *arrive* two per tick. Arrival is bursty on any real connection and on
## localhost: one tick gets one, the next gets three.
##
## `_drain` applied everything in the queue and `_repeat_last` then topped a short
## tick up with the **last command seen**. So a tick that received one command
## applied `[new, stale-repeat]`, and the next tick applied all three of its
## arrivals — **five steps for four commands.** The extra step integrates a
## direction the client never predicted, so reconciliation pulls the pawn back
## along the *previous* input. Reported from the controls as "I press D to go right
## and it feels as if S is tapped in between".
##
## The repeat is right when a command is genuinely **lost**. It is wrong when the
## command is merely **late**, and late is the common case.
func test_a_late_command_is_not_paid_for_twice() -> void:
	_director.enqueue_input(PEER, InputCommand.empty(1))
	_run_frames(2)
	for seq: int in [2, 3, 4]:
		_director.enqueue_input(PEER, InputCommand.empty(seq))
	# One tick. With the catch-up allowance the three arrivals all land here, and a
	# further tick would be genuinely starved — which correctly repeats, and is a
	# different property, asserted in its own test below.
	_run_frames(2)

	var applied: Array = []
	for step: Array in _substeps:
		applied.append(step[1])
	assert_eq(
		applied,
		[1, 2, 3, 4] as Array,
		(
			(
				"four commands became %d substeps: a stale repeat was applied and then the "
				+ "late command was applied on top of it"
			)
			% _substeps.size()
		)
	)


## **A DEFICIT MUST BE REPAYABLE, OR THE SERVER RUNS PERMANENTLY BEHIND.**
##
## Capping the drain at one tick's worth stopped late commands being applied twice
## — but the client produces exactly `_frames_per_tick` per tick, so a server that
## can never apply more than that can never catch up either. Every starved tick
## added permanent lag, and the client sat further and further ahead of the
## server along its own heading.
##
## Measured from the controls with `scripts/debug/net_readout.gd`: a mean
## reconciliation error of **0.068 m while walking**, biased **BACK 0.053** — under
## `TUN-NET-RECONCILE-THRESHOLD`, so it never snapped and never corrected, it just
## sat there.
##
## One extra command per tick is enough: a deficit of N clears in N ticks, and the
## catch-up is bounded so a client that floods cannot make the server sprint.
## **THE FEED NEVER STOPS, WHICH IS THE WHOLE POINT.** An earlier version of this
## test sent a burst and then went quiet, and passed — the queue drained only
## because nothing new arrived. A real client keeps producing
## `_frames_per_tick` commands every tick, so a server that can never apply more
## than that works off a backlog only in the silence between matches.
func test_the_server_keeps_up_with_a_jittery_feed() -> void:
	# Two commands per tick on average, arriving 1/3/2/1/3/2... — the pattern a real
	# connection produces and the one a fixed cap cannot absorb.
	var pattern := [1, 3, 2, 1, 3, 2, 2, 1, 3, 2]
	var seq := 0
	for tick: int in 40:
		for _i: int in int(pattern[tick % pattern.size()]):
			seq += 1
			_director.enqueue_input(PEER, InputCommand.empty(seq))
		_run_frames(2)

	assert_eq(
		_substeps.size(),
		seq,
		(
			(
				"%d commands were sent and %d substeps ran: the server is %d behind and has "
				+ "no way to work it off, so the client sits permanently ahead of it"
			)
			% [seq, _substeps.size(), seq - _substeps.size()]
		)
	)
