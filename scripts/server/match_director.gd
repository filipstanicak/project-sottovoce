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

## One server tick has begun. `ctx.tick` has already advanced.
signal net_ticked(ctx: MatchContext, dt: float)

## An authorised input is to be applied to `peer`'s pawn, at the input rate.
## US-0028 connects the server pawn simulation to this.
signal input_applied(peer: int, command: InputCommand, dt: float)

## The match's context. Constructed here, torn down here, and the only thing a
## system is given.
var ctx := MatchContext.new()

var _systems: Dictionary = {}
var _queues: Dictionary = {}
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
		return
	for stage: StringName in SystemOrder.STAGES:
		_run_stage(stage)


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
func _substep_pawns() -> void:
	for peer: int in _queues.keys():
		var queue: Array = _queues[peer]
		while not queue.is_empty():
			input_applied.emit(peer, queue.pop_front() as InputCommand, MatchContext.step_dt())
