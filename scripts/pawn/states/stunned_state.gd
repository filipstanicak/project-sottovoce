## Stunned. GDD-02 §3.1 and §3.2 rule 2.
##
## **NOTHING INTERRUPTS THIS.** Not another stun, not a kill attempt (which
## simply succeeds), not input. Four seconds of total helplessness is the point
## of the mechanic, not a side effect of it — design law 5 says the prey must
## have teeth, and this is the tooth.
##
## CLAUDE.md never-do #13: never weaken stun to make hunting feel better. If
## hunters are frustrated, make the Anonymous approach more reliable instead.
class_name StunnedState
extends PawnState


func id() -> StringName:
	return PawnStateId.STUNNED


## **THE ONE STATE THAT TAKES THE CAMERA.** GDD-02 §4: control is retained during
## KillAnim, Vault and Drop, and removed here — the view snaps to a fixed offset
## and the player watches whatever is in front of them.
##
## That is the point of a stun. Design law 5 says the prey must have teeth, and
## the teeth are not merely that the hunter stops moving: it is that for the
## whole freeze they cannot even choose where to look while their target walks
## away. Never soften this to make hunting feel better.
func camera_controlled() -> bool:
	return false


## Neutral, like `KillAnim` and for the same reason: the lens reports speed, and
## a stunned player is not moving. The punishment is already the fixed offset and
## four seconds of watching — dramatising it with the lens would spend the
## warning channel on a state the player cannot act on.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


func interrupt_priority() -> int:
	return PRIORITY_COMBAT


## Never, for the full duration. Only a FATAL-priority request — being killed —
## gets through, and that is not an interruption so much as an ending.
func is_interruptible(_ctx: PawnContext) -> bool:
	return false


## Forced to maximum. Everyone nearby now knows exactly what you are, which is
## the other half of the punishment.
func suspicion_rate(_ctx: PawnContext) -> float:
	return 0.0


func enter(ctx: PawnContext) -> void:
	super(ctx)
	ctx.suspicion = Tuning.suspicion.max_value


func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	if ctx.state_timer_ticks >= Tuning.step_ticks(&"TUN-STUN-FREEZE"):
		return PawnStateId.IDLE
	return STAY
