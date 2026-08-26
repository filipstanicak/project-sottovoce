## Dead. GDD-02 §3.1, US-0060.
##
## **THE ONLY STATE WITH NO EXIT OF ITS OWN.** Everything else in the machine
## either ends on a timer or ends on input. This one ends when `SYS-SPAWN` moves
## the pawn to `Respawning` after `TUN-RESPAWN-DELAY` — and `Respawning` does not
## exist yet, so **a player killed today stays dead for the rest of the match.**
## That is US-0062's, and the honest statement is that the kill lands and nothing
## brings you back.
##
## `step()` therefore returns `STAY` unconditionally rather than counting to
## anything. A timer here would be a second authority over how long death lasts,
## sitting in code that is replayed during prediction reconciliation, disagreeing
## with `TUN-RESPAWN-DELAY` the first time either moved.
class_name DeadState
extends PawnState


func id() -> StringName:
	return PawnStateId.DEAD


## FATAL. Nothing outranks it, so nothing can pull a dead player back into the
## world by requesting a transition — the graph's single `Dead -> Respawning`
## edge is the only way out, and it belongs to `SYS-SPAWN`.
func interrupt_priority() -> int:
	return PRIORITY_FATAL


func is_interruptible(_ctx: PawnContext) -> bool:
	return false


## **THE CAMERA STAYS WITH THE PLAYER, AND THAT IS A DESIGN LAW RATHER THAN A
## CONVENIENCE.** The first version of this state took it, on the reasoning that
## a dead player has nothing to aim — and `test_camera_control.gd` refused it,
## because `Stunned` is *the only* state allowed to, and taking the camera on
## death is where a kill-cam starts. Never-do #12 forbids one outright: it would
## convert an earned inference — who was behind me, and how did they get there —
## into a given fact.
##
## So the inherited `true` stands, and the omission below is the statement.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


## **THE VELOCITY IS ZEROED ON ENTRY**, so a player killed mid-stride does not
## coast. `drives_position()` stays false: the body still falls, because a corpse
## that stopped in mid-air over a stairwell reads as a bug rather than as a death.
func enter(ctx: PawnContext) -> void:
	super(ctx)
	ctx.velocity.x = 0.0
	ctx.velocity.z = 0.0


func step(_ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	return STAY
