## **WHEN THE TICK ENDS, AND WHY IT MATTERS.** US-0035, TDD-04 §8.3.
##
## `MatchDirector` has two tick signals and the difference between them was a
## defect for three stories. `net_ticked` fires *before* the stage loop;
## `tick_completed` fires after it. The snapshot builder and the lag-comp history
## both answer "where was everything at tick N", and both must use the second.
##
## **THE SNAPSHOT WAS ON THE FIRST ONE UNTIL US-0035**, while `server_root.gd`
## and `snapshot_builder.gd` each carried a comment claiming it was last in the
## tick. Nothing was broken — the snapshot was internally consistent and the
## measured reconciliation error was 0.00000 m — but it was *labelled* a tick
## ahead of the world it described, so `RemotePawns`, which derives `server_time`
## from `server_tick`, drew every remote 133 ms in the past against a
## `TUN-NET-INTERP-BUFFER` of 100.
##
## Lag compensation is what turned that from a cosmetic mislabel into something
## that had to be fixed: a rewind resolves against a tick the client saw in a
## snapshot, so two timelines would put a silent extra tick into every rewind,
## past the ceiling §8.1 imposes, and nothing would fail until M4.
extends GutTest

var _director: MatchDirector
var _order: Array[String] = []


func before_each() -> void:
	_order = []
	_director = MatchDirector.new()
	add_child_autofree(_director)
	_director.ctx.phase = MatchPhase.Phase.ACTIVE
	_director.net_ticked.connect(func(_c: MatchContext, _d: float) -> void: _order.append("begin"))
	_director.input_applied.connect(
		func(_p: int, _c: InputCommand, _d: float) -> void: _order.append("pawn")
	)
	_director.tick_completed.connect(
		func(_c: MatchContext, _d: float) -> void: _order.append("end")
	)


func _run_frames(count: int) -> void:
	for _i: int in count:
		_director._physics_process(1.0 / Tuning.net.client_input_rate)


func _queue(peer: int, count: int) -> void:
	for i: int in count:
		var command := InputCommand.new()
		command.seq = i + 1
		_director.enqueue_input(peer, command)


func test_the_end_of_the_tick_comes_after_the_pawn_substep() -> void:
	# **THE ASSERTION THE FILE IS FOR**, and the one that was false before
	# US-0035. Measured by emission order rather than reasoned about, because the
	# same claim was reasoned about and written into two comments, and was wrong
	# in both.
	_queue(7, 2)
	_run_frames(2)
	assert_eq(_order, ["begin", "pawn", "pawn", "end"], "the tick's stages ran out of order")


func test_both_signals_fire_exactly_once_per_tick() -> void:
	_run_frames(60)
	var begins := _order.count("begin")
	var ends := _order.count("end")
	assert_eq(begins, 30, "net_ticked did not fire once per tick")
	assert_eq(ends, 30, "tick_completed did not fire once per tick")


func test_nothing_completes_outside_play() -> void:
	# **A LOBBY MUST NOT BE RECORDED.** The clock still advances — a monotonic
	# tick that stopped in the lobby would restart every match at a different
	# number — but a history filled with identical lobby frames would answer a
	# rewind with a world that never happened.
	_director.ctx.phase = MatchPhase.Phase.LOBBY
	_run_frames(60)
	assert_eq(_order.count("begin"), 30, "the clock stopped outside play")
	assert_eq(_order.count("end"), 0, "the tick completed while nothing was simulating")


func test_the_check_can_actually_fail() -> void:
	# Falsification: the recorded order must distinguish the two signals at all.
	# An `_order` that only ever collected one of them would make the first test
	# pass over nothing.
	_queue(7, 1)
	_run_frames(2)
	assert_true(_order.has("begin"), "net_ticked was never observed")
	assert_true(_order.has("end"), "tick_completed was never observed")
	assert_true(_order.has("pawn"), "no pawn substep was observed between them")
