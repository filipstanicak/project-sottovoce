## Holds the fifteen shared state objects and arbitrates transitions.
##
## The concrete states arrive in US-0015 onward; the graph they move through is
## already declared, in `PawnTransitions`.
##
## `step()` REQUESTS a transition; the machine VALIDATES it (TDD-06 §2.2). A
## state deliberately does not know the graph — that is what keeps the graph in
## one readable place instead of scattered across fifteen files, which is the
## state pattern's one real weakness and the reason ADR-0008 centralises it.
##
## Extends Node so it can live in the pawn scene, but its logic touches nothing
## outside `ctx`: this script runs during prediction reconciliation, where
## reading the tree would produce a different answer on the replay.
class_name PawnStateMachine
extends Node

## Emitted after a transition completes. Presentation listens; nothing in
## `scripts/pawn/` does.
signal state_changed(from: StringName, to: StringName)

## The states that exist today. US-0020 onward fill in the rest; a pawn entering
## an unregistered state is caught by `step()` rather than crashing, because a
## half-registered machine during M1 is a normal intermediate condition.
##
## `Climb` and `Drop` are still missing, so a traverse pressed at a façade or an
## edge push_errors instead of moving. That noise is deliberate: the alternative
## is silence, and silence is indistinguishable from the resolver being wrong.
const REGISTERED: Array[GDScript] = [
	preload("res://scripts/pawn/states/idle_state.gd"),
	preload("res://scripts/pawn/states/blend_walk_state.gd"),
	preload("res://scripts/pawn/states/stroll_state.gd"),
	preload("res://scripts/pawn/states/jog_state.gd"),
	preload("res://scripts/pawn/states/run_state.gd"),
	preload("res://scripts/pawn/states/sprint_state.gd"),
	preload("res://scripts/pawn/states/vault_state.gd"),
	preload("res://scripts/pawn/states/blended_state.gd"),
	preload("res://scripts/pawn/states/kill_anim_state.gd"),
	preload("res://scripts/pawn/states/stunned_state.gd"),
]

## id -> PawnState. ONE INSTANCE PER STATE, shared by every pawn.
var _states: Dictionary = {}


func _ready() -> void:
	for script: GDScript in REGISTERED:
		register(script.new())


## Register a state object. Asserts the key matches the object's own `id()`,
## because a state registered under the wrong name makes every transition to
## that name go somewhere else while looking correct at the call site.
func register(state: PawnState) -> void:
	var key := state.id()
	assert(key != PawnState.STAY, "a PawnState must override id()")
	assert(PawnStateId.exists(key), "unknown state id: %s" % key)
	assert(not _states.has(key), "state %s registered twice" % key)
	_states[key] = state


func has_state(id: StringName) -> bool:
	return _states.has(id)


func state_count() -> int:
	return _states.size()


func state_for(id: StringName) -> PawnState:
	return _states.get(id)


## Whether the pawn's current state writes its own position. The driver asks
## before integrating; see `PawnState.drives_position`.
func drives_position(ctx: PawnContext) -> bool:
	var current: PawnState = _states.get(ctx.state_id)
	return current != null and current.drives_position()


## Advance one tick. Returns the id the pawn is in afterwards.
func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	var current: PawnState = _states.get(ctx.state_id)
	if current == null:
		push_error("pawn is in unregistered state %s" % ctx.state_id)
		return ctx.state_id
	ctx.state_timer_ticks += 1
	# Before the state runs, so a traverse pressed early is already armed when the
	# state that could honour it looks. Inside step() deliberately: the buffer
	# changes the simulation, and a client-only one predicts vaults the server
	# never performed (TDD-06 §3).
	PawnInputBuffer.tick(ctx, input)
	# The other half of the ~0.45 s window: the buffer above forgives pressing
	# EARLY, this forgives pressing late. Probe-driven rather than input-driven,
	# and in step() for the same reason — it changes what the simulation does.
	TraversalResolver.tick_magnet(ctx)
	var requested := current.step(ctx, input, delta)
	if requested != PawnState.STAY:
		# NOT an interruption. A state asking to leave is COMPLETION, and gating it
		# on `is_interruptible()` deadlocks every state that declines to be
		# interrupted: it refuses its own exit and holds the pawn forever.
		# `Vault` and `KillAnim` were both built that way and neither could end.
		transition(ctx, requested, current.interrupt_priority(), false)
	return ctx.state_id


## Place a pawn into `id` with no edge check, and run its `enter()`.
##
## **SPAWNING IS NOT A TRANSITION.** There is no state to come *from*: a pawn
## being placed in the world has no history, and asking the graph to justify the
## move would be asking it a question it does not model. `PawnContext` starts in
## `Respawning`, which is `SYS-SPAWN`'s state and does not exist until US-0062;
## routing a spawn through `transition()` therefore looked up a state that was
## not registered and took the whole boot down with it — with 222 tests green.
##
## Returns false for an unregistered target, so a caller cannot leave a pawn in a
## state nothing can step.
func spawn_into(ctx: PawnContext, id: StringName) -> bool:
	if not _states.has(id):
		push_error("cannot spawn into unregistered state %s" % id)
		return false
	var from := ctx.state_id
	ctx.state_id = id
	_states[id].enter(ctx)
	state_changed.emit(from, id)
	return true


## Validate and perform a transition. Returns whether it happened.
##
## An illegal request ASSERTS in debug and push_errors in release. It is a
## programming error, not a runtime condition: `step()` asked for somewhere the
## graph does not go, and silently clamping that to "stay put" would hide the
## bug behind a pawn that occasionally ignores input.
##
## `interrupting` is false when the CURRENT state asked to leave. Interruption is
## something done TO a state by something else; a state ending is not that, and
## checking `is_interruptible()` on a state's own exit makes every
## uninterruptible state permanent.
func transition(ctx: PawnContext, to: StringName, priority: int, interrupting: bool = true) -> bool:
	if to == PawnState.STAY:
		return false
	if not _states.has(to):
		push_error("transition to unregistered state %s" % to)
		return false
	if not _states.has(ctx.state_id):
		# The FROM state is unregistered. During M1 that is a normal intermediate
		# condition — six states arrive in US-0017+ — and it must not crash the
		# lookup below. Use `spawn_into()` to place a pawn without an edge.
		push_error("transition FROM unregistered state %s" % ctx.state_id)
		return false
	if not is_valid_edge(ctx.state_id, to):
		assert(false, "Illegal transition %s -> %s (TDD-06 §2.2)" % [ctx.state_id, to])
		push_error("Illegal transition %s -> %s" % [ctx.state_id, to])
		return false

	var current: PawnState = _states[ctx.state_id]
	if interrupting and not current.is_interruptible(ctx):
		if priority <= current.interrupt_priority():
			return false

	var from := ctx.state_id
	current.exit(ctx)
	ctx.state_id = to
	_states[to].enter(ctx)
	state_changed.emit(from, to)
	return true


## Whether `from -> to` is a legal edge, per the centralised table asserted
## against the normative diagram in GDD-02 §3.
func is_valid_edge(from: StringName, to: StringName) -> bool:
	return PawnTransitions.allows(from, to)
