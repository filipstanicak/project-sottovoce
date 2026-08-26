## **WHAT THE CLIENT THOUGHT WAS TRUE AFTER ONE COMMAND.** TDD-04 §4.2, US-0032.
##
## PURE, and deliberately a *value*: a copy taken at a moment, never a live
## reference. `PawnContext` is one long-lived object the state machine rewrites
## sixty times a second, so a history holding references would rewrite its own
## past every frame and reconciliation would always agree with itself.
##
## **ONLY THE PREDICTED SUBSET.** Position, velocity, the state machine's state
## and whether the pawn was grounded — the things `PawnMotion` computes from an
## `InputCommand`. Suspicion, tier, cooldowns, contracts and score are absent
## because **nothing gameplay-relevant is predicted** (ADR-0002 point 5), and the
## way to keep that true is to have nowhere to put them.
class_name PredictedState
extends RefCounted

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var state_id: StringName = PawnStateId.IDLE
var state_timer_ticks: int = 0
var grounded: bool = false


## Copy the predicted subset out of a live context.
static func capture(ctx: PawnContext) -> PredictedState:
	var out := PredictedState.new()
	out.position = ctx.position
	out.velocity = ctx.velocity
	out.state_id = ctx.state_id
	out.state_timer_ticks = ctx.state_timer_ticks
	out.grounded = ctx.grounded
	return out


## Build one from the server's authoritative block.
static func from_snapshot(snapshot: Snapshot) -> PredictedState:
	var out := PredictedState.new()
	out.position = snapshot.own_position
	out.velocity = snapshot.own_velocity
	out.state_id = snapshot.own_state
	out.state_timer_ticks = snapshot.own_state_timer
	out.grounded = snapshot.own_grounded
	return out


## Write it into a live context and onto the body.
##
## **THE BODY TOO, NOT ONLY THE CONTEXT.** `PawnMotion` reads `body.is_on_floor()`
## and moves from `body.global_position`; a replay that snapped the context and
## left the body where it was would integrate from the position the correction
## just rejected.
func apply_to(ctx: PawnContext) -> void:
	ctx.position = position
	ctx.velocity = velocity
	ctx.state_id = state_id
	ctx.state_timer_ticks = state_timer_ticks
	ctx.grounded = grounded
	if ctx.body != null:
		ctx.body.global_position = position
		ctx.body.velocity = velocity


## How far apart two predictions are, in metres. Position only: it is what
## `TUN-NET-RECONCILE-THRESHOLD` is expressed in, and a velocity that differs
## while the position agrees corrects itself on the next tick anyway.
func error_against(other: PredictedState) -> float:
	return position.distance_to(other.position)


## **DO THE TWO AGREE ABOUT WHICH STATE THE PAWN IS IN?** A separate question
## from `error_against`, and US-0060 is what made it load-bearing.
##
## Both peers run the same machine from the same commands, so in the ordinary case
## they agree and this costs one comparison. What it catches is the case the
## distance cannot see: the **server put the pawn somewhere the client had no way
## to predict** — `KillAnim` on a validated kill, `Dead` at a contact frame,
## `Stunned`, `Respawning`. All four happen to a pawn that may be standing
## perfectly still, so the positional error is **0.000 m**, and a reconciler that
## compared only distance would return early and never apply `own_state` at all.
##
## The symptom would have been "I pressed kill and my character kept walking",
## with no error anywhere and every existing test green.
func same_state_as(other: PredictedState) -> bool:
	return state_id == other.state_id
