## **ONE STEP OF THE PAWN, SHARED BY THE CLIENT AND THE SERVER.** TDD-06 §7,
## ADR-0008, US-0028.
##
## Refresh the probes, step the state machine, move the body, write back what
## actually happened. Both drivers call this and neither has its own copy.
##
## **THAT IS THE WHOLE POINT.** ADR-0008 requires the server and the client's
## prediction to run the same `PawnStateMachine` and the same `PawnState`
## classes, and they always did — but *stepping* the machine is only half of a
## tick. The other half is the fifteen lines that decide whether a traversal owns
## its position, when gravity is applied, and what is written back from the
## physics body. Two copies of those fifteen lines is a divergence in prediction
## with a green suite either side of it: every unit test calls `step()` directly
## and never reaches this at all (trap 7's family).
##
## Not a `Node`. It takes the body it is given and never looks one up, so it obeys
## `scripts/pawn/`'s rule that this code is replayed during reconciliation and
## must be deterministic: no `get_node`, no `get_tree`, no clock, and no autoload
## but `Tuning`.
class_name PawnMotion
extends RefCounted


## Advance one substep. `delta` is the INPUT rate on both peers — see
## `MatchDirector._substep_pawns` for why a single step of twice the length is
## not the same thing.
##
## Probes are refreshed **before** `step()` and by the caller's frame, not by a
## state: raycasts are only valid inside the physics step, and a state casting
## its own would cast again on every reconciliation replay — the same query
## against a world that has since moved on.
static func advance(
	ctx: PawnContext,
	machine: PawnStateMachine,
	probes: TraversalProbes,
	body: CharacterBody3D,
	command: InputCommand,
	delta: float
) -> void:
	probes.refresh(ctx)
	machine.step(ctx, command, delta)
	apply(ctx, machine, body, command, delta)


## Move the body from the velocity the state machine computed, and write back
## what actually happened.
##
## **THE WRITE-BACK IS NOT BOOKKEEPING.** A pawn that walked into a wall has a
## velocity the simulation must know about, or the next tick accelerates from a
## speed it never reached — and the client, which did hit the wall, would
## reconcile against a server that did not.
static func apply(
	ctx: PawnContext,
	machine: PawnStateMachine,
	body: CharacterBody3D,
	command: InputCommand,
	delta: float
) -> void:
	ctx.yaw = command.look_yaw
	body.rotation.y = ctx.yaw
	if machine.drives_position(ctx):
		# A traversal owns its own position: a fixed displacement against static
		# geometry, planned once and interpolated. Running move_and_slide() here
		# with the velocity frozen would leave the body where it stood and then
		# overwrite the plan with it — a vault that computes a perfect arc and
		# never moves the pawn (trap 7).
		body.global_position = ctx.position
		body.velocity = Vector3.ZERO
		return
	body.velocity = ctx.velocity
	if not ctx.grounded or not body.is_on_floor():
		body.velocity.y -= Tuning.gravity * delta
	body.move_and_slide()
	ctx.velocity = body.velocity
	ctx.position = body.global_position
	ctx.grounded = body.is_on_floor()
