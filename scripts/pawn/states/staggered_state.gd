## Staggered — **your own action failed**, and you are paying for it. ADR-0017,
## GDD-02 §3.1.
##
## **`Stunned` IS DONE TO YOU BY ANOTHER PLAYER; `Staggered` IS DONE TO YOU BY
## YOUR OWN FAILED ACTION.** That one line is the whole distinction between two
## states whose names sit one letter apart, and it is the first thing to check if
## a punishment ever appears to land on the wrong player.
##
## Three rules enter it, each with its own duration and none with its own name:
## `TUN-KILL-CONTEST-STAGGER` 1.5 s, `TUN-STUN-INVALID-STAGGER` 2.0 s and — when
## `ABIL-LUNGE` lands (US-0070) — `TUN-LUNGE-WHIFF-STAGGER` 1.2 s. All three had
## been in `TUNABLES.md` since M0 with nowhere to live.
##
## **IT IS NEVER ENTERED BY INPUT.** There is no press that reaches here; every
## edge into it is a system reporting that something the player committed to did
## not work.
##
## **THE LOCKOUT IS THE RULE AND THIS IS THE TELL.** `CombatLockouts.stagger`
## still answers *may this player initiate*, and it must, because both combat
## systems have to answer that with no state machine in reach (every unit
## fixture). What this adds is the half a lockout cannot have: `state_id` is on
## the wire in every remote pawn record and `CombatLockouts` is on nobody's, so
## before this state a prey who read a Lunge and watched the hunter whiff saw
## them **stand up and walk away normally**. A punishment nobody can see teaches
## nobody anything.
class_name StaggeredState
extends PawnState


func id() -> StringName:
	return PawnStateId.STAGGERED


func interrupt_priority() -> int:
	return PRIORITY_COMBAT


## **THE CAMERA IS KEPT, AND `Stunned` MUST REMAIN THE ONLY STATE THAT TAKES
## IT.** `StunnedState`'s own docstring: *"the teeth are not merely that the
## hunter stops moving: it is that for the whole freeze they cannot even choose
## where to look while their target walks away."* That is the stun's signature.
## A staggered player watches their prey leave **and can look at them**, which is
## a materially smaller punishment and reads as one.
func camera_controlled() -> bool:
	return true


## Neutral, like every other combat state. The lens reports speed and a staggered
## player is not moving; dramatising it here would spend the warning channel on a
## state the player cannot act on.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


## **YES, AND THAT IS NEVER-DO #13 RATHER THAN A PREFERENCE.** A state that
## declined a stun would narrow what a stun can reach: a whiffed lunger would
## otherwise be in a locomotion state, which is stunnable, so putting them
## somewhere stun cannot follow is a weakening dressed as an addition.
##
## **IT IS ASYMMETRIC WITH `StunAnim`, AND THE ASYMMETRY IS A RULE: you are
## protected while DOING something, not while PAYING for having done it.**
## `KillAnim` and `StunAnim` decline COMBAT because commitment is the mechanic;
## `Stunned` declines it because a re-stunnable player could be chain-locked out
## of the match by two opponents. Neither is true of a 1.2-2.0 s recovery the
## staggered player caused themselves.
func is_interruptible(_ctx: PawnContext) -> bool:
	return true


## **STEP TICKS, NOT NET TICKS** — trap 9. `state_timer_ticks` advances inside
## `step()` at the 60 Hz input rate, and `stagger_ticks` is written in the same
## domain by `ceiling_ticks()` below.
##
## **A ZERO OR NEGATIVE TOTAL FALLS BACK TO THE CEILING RATHER THAN ENDING THE
## STATE.** A pawn placed here with nothing written would otherwise leave on its
## first step, which is a punishment that silently does not happen — trap 17's
## family, in a state instead of in a `.tres`.
func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	var total := ctx.stagger_ticks if ctx.stagger_ticks > 0 else ceiling_ticks()
	if ctx.state_timer_ticks >= total:
		return PawnStateId.IDLE
	return STAY


## The longest stagger any rule can produce, in **step** ticks.
##
## **DERIVED, NEVER CHOSEN.** A fourth number here could be set to a value the
## three real ones contradict. It is what a client uses when it has been forced
## into this state by a snapshot and has not been told the total — see
## `PawnContext.stagger_ticks` for why that can only ever end the state late.
##
## **PUBLIC BECAUSE IT IS THE ANSWER WORTH TESTING.** A test that re-derived it
## would agree with a ceiling that had drifted below one of the three.
static func ceiling_ticks() -> int:
	var contest := Tuning.step_ticks(&"TUN-KILL-CONTEST-STAGGER")
	var flail := Tuning.step_ticks(&"TUN-STUN-INVALID-STAGGER")
	var whiff := Tuning.step_ticks(&"TUN-LUNGE-WHIFF-STAGGER")
	return maxi(contest, maxi(flail, whiff))
