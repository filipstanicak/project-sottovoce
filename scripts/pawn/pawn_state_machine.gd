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

## id -> PawnState. ONE INSTANCE PER STATE, shared by every pawn.
var _states: Dictionary = {}


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


## Advance one tick. Returns the id the pawn is in afterwards.
func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	var current: PawnState = _states.get(ctx.state_id)
	if current == null:
		push_error("pawn is in unregistered state %s" % ctx.state_id)
		return ctx.state_id
	ctx.state_timer_ticks += 1
	var requested := current.step(ctx, input, delta)
	if requested != PawnState.STAY:
		transition(ctx, requested, current.interrupt_priority())
	return ctx.state_id


## Validate and perform a transition. Returns whether it happened.
##
## An illegal request ASSERTS in debug and push_errors in release. It is a
## programming error, not a runtime condition: `step()` asked for somewhere the
## graph does not go, and silently clamping that to "stay put" would hide the
## bug behind a pawn that occasionally ignores input.
func transition(ctx: PawnContext, to: StringName, priority: int) -> bool:
	if to == PawnState.STAY:
		return false
	if not _states.has(to):
		push_error("transition to unregistered state %s" % to)
		return false
	if not is_valid_edge(ctx.state_id, to):
		assert(false, "Illegal transition %s -> %s (TDD-06 §2.2)" % [ctx.state_id, to])
		push_error("Illegal transition %s -> %s" % [ctx.state_id, to])
		return false

	var current: PawnState = _states[ctx.state_id]
	if not current.is_interruptible(ctx) and priority <= current.interrupt_priority():
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
