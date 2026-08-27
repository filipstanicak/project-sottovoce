## Respawning. GDD-02 §3.1 and the §3 diagram's `Dead --> Respawning` and
## `Respawning --> Idle` edges. US-0062.
##
## **THIS STATE IS THE `TUN-RESPAWN-DELAY`, NOT THE INVULNERABILITY.** GDD-02
## §3.1's own row gives its exit condition as *"`TUN-RESPAWN-DELAY` 5.0 s"* and
## its priority as FATAL. `TUN-RESPAWN-INVULN` is a separate, shorter window that
## begins **after** this state ends, when the player is back in `Idle` and can
## actually be shot at; it lives in `CombatLockouts` because both combat systems
## have to read it and neither of them reads pawn states for permission.
##
## **`Dead` IS ONE TICK IN PRACTICE, AND THAT IS THE DIAGRAM'S OWN SHAPE.**
## `Dead`'s exit condition is *"corpse spawned"*, and the corpse is registered in
## the tick the kill resolves — so a victim passes through `Dead` on the contact
## frame and spends the five seconds here. Until US-0062 there was no edge out of
## `Dead` at all and a killed player stayed dead for the rest of the match.
##
## **NOTHING IN HERE COUNTS ANYTHING, AND THE ABSENCE IS THE RULE.** `step()`
## returns `STAY` forever and the **server** drives both edges. A state that timed
## itself out would have the client predicting the end of its own death — and the
## position it lands at is chosen server-side from the *live* lobby at the moment
## the timer expires, which a client cannot know and must not guess. That is
## never-do #3 with a five-second head start.
class_name RespawningState
extends PawnState


func id() -> StringName:
	return PawnStateId.RESPAWNING


## FATAL, like `Dead`. A player waiting out their respawn is not a target, is not
## interruptible, and cannot be pushed into anything by a combat system.
func interrupt_priority() -> int:
	return PawnState.PRIORITY_FATAL


func is_interruptible(_ctx: PawnContext) -> bool:
	return false


## Neutral, like every other non-locomotion state. The lens reports speed and a
## respawning player has none.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


## **THE CAMERA STAYS WITH THE PLAYER**, unlike `Stunned`. `test_camera_control.gd`
## allows exactly one state to take it, and taking it here would be a death camera
## by another name — never-do #12's kill-cam ban is about what a dead player is
## shown, not only about a replay.
func step(_ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	return STAY
