## Choking — **caught in somebody else's Cinderfall cloud.** ADR-0023, US-0104,
## GDD-02 §3.1.
##
## The reference's cloud makes everybody inside it but the caster double over
## coughing, unable to run or fight back, for as long as it stands, and that
## includes anybody who walks in after the burst. This is that.
##
## **NEITHER `Staggered` NOR `Stunned`, AND THE DIFFERENCE IS WHO DID IT AND FOR
## HOW LONG.** `Staggered` is your own failed action, for a fixed duration.
## `Stunned` is another player's stun, a fixed 4 s, with the camera taken. This is
## another player's ability, held for **however long the cloud has left**, which
## no fixed number can say, so the state has no exit of its own.
##
## **THE SERVER ENDS IT, AND A CLIENT CAN ONLY EVER END IT LATE.**
## `CinderfallCatch` releases the pawn into `Idle` on the tick no live cloud holds
## it, and the snapshot carries the state. A predicting client replaying inputs
## here stays here until it is told otherwise, which is the safe direction:
## `StaggeredState`'s ceiling makes the same choice.
##
## **THE CAMERA IS KEPT.** Taking it is the stun's signature (`StunnedState`), and
## a coughing figure can still look at whoever threw the cloud.
class_name ChokingState
extends PawnState


func id() -> StringName:
	return PawnStateId.CHOKING


func interrupt_priority() -> int:
	return PRIORITY_COMBAT


func camera_controlled() -> bool:
	return true


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


## **YES: a caught figure can be stunned and killed**, and the kill is the point
## of the ability. Never-do #13 forbids anything a stun could not reach.
func is_interruptible(_ctx: PawnContext) -> bool:
	return true


func enter(ctx: PawnContext) -> void:
	super(ctx)
	_hold(ctx)


## Held where it stands, every step. Gravity is the body's, so the vertical is
## left alone.
func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	_hold(ctx)
	return STAY


static func _hold(ctx: PawnContext) -> void:
	ctx.velocity = Vector3(0.0, ctx.velocity.y, 0.0)
