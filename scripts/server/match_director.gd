## **THE SERVER'S CLOCK AND ITS ORDER.** TDD-01 §4, TDD-03, US-0027. SERVER ONLY.
##
## One net tick every second physics frame — 30 Hz derived from 60, never
## measured. Everything gameplay-relevant happens inside `_net_tick()`, in the
## order `SystemOrder` declares, and nothing at all happens in `_process`.
##
## **DERIVED, NOT TIMED.** A director that accumulated `delta` and fired when it
## passed 33.3 ms would drift, would fire twice in a frame after a hitch, and
## would produce a different tick count on two machines running the same match.
## The tick is a *count of physics frames divided by two*: exact, reproducible,
## and identical on the server and in a client's replay.
##
## **THE PAWN SUBSTEP IS THE ONE THING THAT IS NOT 30 Hz**, and it is not an
## optimisation. Prediction replays buffered inputs through the same state
## machine the server used; a server integrating once at dt = 1/30 while the
## client predicted twice at dt = 1/60 diverges on every acceleration curve, and
## at `TUN-SPEED-ACCEL` 18 m/s² that divergence is immediate and permanent. So
## the server steps **once per received `InputCommand`**, at the input rate,
## exactly as the client did.
##
## **SIGNALS, NOT CALLS**, the same as `RpcRouter` and for the same reason: this
## file must not need editing every time a system or a pawn is added, because
## every edit is a chance to get the order wrong.
class_name MatchDirector
extends Node

## One server tick has **begun**. `ctx.tick` has already advanced, and nothing
## has simulated yet — anything listening here sees the world as the tick found
## it.
signal net_ticked(ctx: MatchContext, dt: float)

## One server tick has **ended**: every stage has run and the world is at rest.
##
## **THE DISTINCTION IS NOT COSMETIC, AND IT WAS WRONG FOR THREE STORIES.** The
## snapshot builder and the lag-comp history both answer "where was everything at
## tick N", and both were — or would have been — connected to `net_ticked`, which
## fires *before* the pawn substep. A snapshot stamped N then carried the world
## from the end of N-1, and `server_root.gd` and `snapshot_builder.gd` each
## carried a comment claiming the opposite.
##
## Measured before it was changed: the client's own reconciliation error was
## **0.00000 m**, because the snapshot was internally consistent — its position
## and its `last_acked_seq` described the same moment. Nothing was broken. What
## was wrong was the *label*: `RemotePawns` derives `server_time` from
## `snapshot.server_tick`, so every remote entity was drawn one tick further into
## the past than `TUN-NET-INTERP-BUFFER` declares — an effective 133 ms against a
## documented 100.
##
## Lag compensation is why it had to be fixed rather than documented. It rewinds
## to a tick the client observed, and §8.1's ceiling exists to cap how far into
## the past a player may reach. A history stamped on a different timeline from the
## snapshots would have added a silent tick to *every* rewind, past that ceiling,
## and nothing would have failed until M4.
signal tick_completed(ctx: MatchContext, dt: float)

## An authorised input is to be applied to `peer`'s pawn, at the input rate.
## US-0028 connects the server pawn simulation to this.
signal input_applied(peer: int, command: InputCommand, dt: float)

## The match's context. Constructed here, torn down here, and the only thing a
## system is given.
var ctx := MatchContext.new()

var _systems: Dictionary = {}
var _queues: Dictionary = {}
var _last_command: Dictionary = {}
var _frames_per_tick: int = 2
var _frame: int = 0


func _ready() -> void:
	_frames_per_tick = maxi(int(round(Tuning.net.client_input_rate / Tuning.net.server_tick)), 1)
	_warn_if_the_engine_disagrees()
	set_process(false)


## **THE PHYSICS RATE IS PART OF THE CONTRACT.** The net tick is a division of
## it, so an engine running physics at 30 or 120 silently halves or doubles the
## server's rate — every duration in `TUN-` seconds still converts correctly, and
## every one in ticks does not. `project.godot` pins it and
## `test_project_settings_pinned.gd` guards the pin; this catches the case where
## something changed it at runtime.
func _warn_if_the_engine_disagrees() -> void:
	var engine_rate := float(Engine.physics_ticks_per_second)
	if not is_equal_approx(engine_rate, Tuning.net.client_input_rate):
		Log.error(
			(
				"MatchDirector: physics runs at %.1f Hz but TUN-NET-CLIENT-INPUT-RATE is %.1f"
				% [engine_rate, Tuning.net.client_input_rate]
			),
			&"net"
		)


## Queue an authorised input. Connected to `RpcRouter.input_received`.
##
## **THE QUEUE IS CAPPED AND DROPS THE OLDEST.** A client that stalls for two
## seconds and then dumps its backlog must not buy itself a hundred substeps of
## catch-up in one tick — that is a hitch for everyone else and a speed advantage
## for the stalling player. `TUN-NET-INPUT-BUFFER-SIZE` is the same 32 commands
## the client's own reconciliation ring holds, which is the most input that can
## still be reconciled; beyond it the oldest is worthless anyway.
func enqueue_input(peer: int, command: InputCommand) -> void:
	if not _queues.has(peer):
		_queues[peer] = []
	var queue: Array = _queues[peer]
	queue.append(command)
	while queue.size() > Tuning.net.input_buffer_size:
		queue.pop_front()


## Register a system under its declared stage. Refuses a system with no stage,
## and refuses one claiming a stage no system may occupy — `ingest`, `pawn` and
## `snapshot` are positions in the order, not places to hang behaviour.
func register(system: GameSystem) -> bool:
	var stage := system.stage()
	if not SystemOrder.is_a_system_stage(stage):
		Log.error("MatchDirector: %s declares no valid stage" % system.name, &"net")
		return false
	if _systems.has(stage):
		Log.error("MatchDirector: two systems claim the %s stage" % stage, &"net")
		return false
	_systems[stage] = system
	system.setup(ctx)
	return true


func system_for(stage: StringName) -> GameSystem:
	return _systems.get(stage, null)


func forget(peer: int) -> void:
	_queues.erase(peer)
	_last_command.erase(peer)


## How many commands are waiting for `peer`. For tests and diagnostics.
func queued_for(peer: int) -> int:
	return (_queues.get(peer, []) as Array).size()


func teardown() -> void:
	for stage: StringName in _systems:
		(_systems[stage] as GameSystem).teardown()
	_systems.clear()
	_queues.clear()


## **THE ONLY CLOCK.** Every second physics frame is a net tick; the rest do
## nothing at all. Counting frames rather than accumulating time is what makes
## the rate exact — 10 000 frames are 5 000 ticks, with no drift to measure.
func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame < _frames_per_tick:
		return
	_frame = 0
	_net_tick()


## One server tick, in the order TDD-01 §4 declares.
##
## The stages are walked from `SystemOrder.STAGES` rather than written out here,
## so the order has exactly one definition and the guard can compare it against
## the document.
func _net_tick() -> void:
	ctx.tick += 1
	net_ticked.emit(ctx, MatchContext.net_dt())
	if not MatchPhase.is_simulating(ctx.phase):
		# The clock still advances — a monotonic tick that stopped in the lobby
		# would restart every match at a different number — but nothing simulates.
		# **AND NOTHING RECORDS.** `tick_completed` is not emitted here: a lag-comp
		# history filled with identical lobby frames would answer a rewind with a
		# world that never happened, and a snapshot of a match that has not started
		# describes nothing.
		return
	for stage: StringName in SystemOrder.STAGES:
		_run_stage(stage)
	tick_completed.emit(ctx, MatchContext.net_dt())


func _run_stage(stage: StringName) -> void:
	match stage:
		&"pawn":
			_substep_pawns()
		&"ingest", &"snapshot":
			# Positions in the order, owned elsewhere: the router drains into the
			# queues as messages arrive, and US-0030 builds the snapshot.
			pass
		_:
			var system: GameSystem = _systems.get(stage, null)
			if system != null:
				system.tick(ctx, MatchContext.net_dt())


## **ONCE PER RECEIVED COMMAND, AT THE INPUT RATE.** Not once per tick, and not
## once per tick with a doubled `dt`: the client integrated two separate steps
## with a decision between them, and a single step of twice the length lands
## somewhere else on any curve that is not linear.
##
## **A MISSING COMMAND REPEATS THE LAST ONE RATHER THAN STALLING**, US-0028. A
## stalled pawn produces a position the client cannot have predicted — it kept
## walking — so every dropped packet would guarantee a reconciliation, and a
## player on a lossy connection would stutter continuously against a server that
## was merely waiting.
##
## **THE ORIGINAL JUSTIFICATION FOR THE REPEAT WAS WRONG AND IS WORTH CORRECTING**:
## it said "repeating is what the client's own prediction did with that tick, so
## the two agree". The client never *has* a missing command — it always holds its
## own input — so a repeat is a step the client did not predict. It is right only
## when a command is genuinely **lost**, and wrong when the command is merely
## **late**. `_drain` is what keeps the two apart: it applies at most one tick's
## worth, so a late command is used next tick rather than arriving on top of a
## repeat that already stood in for it.
##
## Walks `ctx.pawns`, not the queues: a peer with a pawn and an empty queue is
## exactly the case that needs filling, and it has no queue entry to be found by.
func _substep_pawns() -> void:
	for peer: int in _ctx_pawn_peers():
		var applied := _drain(peer)
		_repeat_last(peer, applied)


func _ctx_pawn_peers() -> Array:
	return ctx.pawns.keys() if not ctx.pawns.is_empty() else _queues.keys()


## What the peer sent, in sequence order, **capped at one tick's worth**.
##
## **IT USED TO DRAIN THE WHOLE QUEUE, AND THAT PAID FOR LATE COMMANDS TWICE.**
## The client sends at `TUN-NET-CLIENT-INPUT-RATE` and the server ticks at
## `TUN-NET-SNAPSHOT-RATE`, so exactly `_frames_per_tick` commands *exist* per tick
## — but they do not *arrive* that way. Arrival is bursty on any connection and on
## localhost too: one tick receives one command, the next receives three.
##
## Draining everything meant a short tick applied its one command and then
## `_repeat_last` filled the gap with a **stale** repeat — and the next tick applied
## all three of its arrivals on top. **Five steps for four commands**, with the
## extra one integrating a direction the client never predicted. Measured directly:
## the applied sequence read `[1, 1, 2, 3, 4]`.
##
## The client feels that as a tug toward its *previous* input, because that is
## literally what the extra step is. Reported from the controls as "I press D to go
## right and it feels as if S is tapped in between", one build after the render
## interpolation was fixed and stopped masking it.
##
## Surplus arrivals stay queued for the next tick, where they are applied instead
## of a repeat. The queue is already bounded by `TUN-NET-INPUT-BUFFER-SIZE`, so
## holding them back cannot grow it without limit.
func _drain(peer: int) -> int:
	var queue: Array = _queues.get(peer, [])
	var applied := 0
	while not queue.is_empty() and applied < _frames_per_tick:
		var command := queue.pop_front() as InputCommand
		_last_command[peer] = command
		input_applied.emit(peer, command, MatchContext.step_dt())
		applied += 1
	return applied


## Fill the tick with the last command seen, **and only when nothing at all
## arrived.** Nothing is repeated for a peer that has never sent one — there is no
## intent to extend, and a pawn that has not yet moved must not start.
##
## **"FEWER THAN A FULL TICK" IS NOT THE SAME QUESTION AS "NOTHING ARRIVED", AND
## USING THE FIRST WAS THE DEFECT.** Arrival is bursty, so a tick receiving one of
## its two commands is the ordinary case, not a starved one — the second is in
## flight and lands next tick. Repeating there inserts a step the client never
## predicted *and* the real command still gets applied afterwards.
##
## Letting a short tick simply be short is self-correcting: the surplus that
## `_drain` holds back becomes a one-command cushion within a few ticks, after
## which jitter no longer starves the peer at all. A repeat is then what it was
## always meant to be — the answer to a command that is **lost**, not one that is
## late.
func _repeat_last(peer: int, applied: int) -> void:
	if applied > 0 or not _last_command.has(peer):
		return
	var command := _last_command[peer] as InputCommand
	for _i: int in _frames_per_tick - applied:
		input_applied.emit(peer, command, MatchContext.step_dt())
