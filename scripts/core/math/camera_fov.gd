## The FOV ladder. GDD-02 §4.2.
##
## **THIS IS A WARNING SYSTEM, NOT A STYLE CHOICE.** 55° blend-walk → 60° stroll
## → 69° run → 72° sprint. Four rungs since the Jog rung was deprecated, and the
## nine-degree step from stroll to run is the ladder's cliff made visible.
##
## The widening lens produces peripheral distortion and a sense of loss of
## control that tells the player they are doing
## something conspicuous *before* they read the tier indicator — the cheapest
## possible reinforcement of design law 1, speed is spent anonymity.
##
## The narrow end does the opposite job, and it is the half that is easy to
## forget: blend-walk COMPRESSES the scene, making distant faces larger and more
## comparable. Slowing down literally lets you see more clearly. That is the
## game's thesis rendered as a lens, and it is why the ladder must never be
## re-centred to make sprinting feel better.
##
## PURE, and deliberately tiny. Which value applies belongs to the pawn's state —
## every `PawnState` returns its own `camera_fov()` — so all that is left here is
## how fast the lens may move and what replaces the ladder when a player cannot
## tolerate it moving at all.
class_name CameraFov
extends RefCounted


## What the lens should be showing, given the state's rung, the crowd-scan input
## and the accessibility mode.
##
## **SCAN WINS.** GDD-02 §9.4 disables FOV changes *with speed* — the ladder,
## which moves constantly without being asked. Crowd-scan is a change the player
## requests by holding a button, and it is the game's central act; taking it away
## from motion-reduction players would hand them §9.4's own failure mode 9, a
## competitive disadvantage bought with an accessibility setting. One line to
## reverse if that reading is ever judged wrong.
##
## **MOTION REDUCTION REPLACES THE LADDER, IT DOES NOT DAMP IT.** A slower blend
## would still sweep the same 17°, which is the part that makes people ill —
## §9.4 locks the value instead. The trade is real and stated to the player: the
## warning channel goes away, and a persistent speed indicator is added to the
## HUD in its place (US-0084). A *different* channel, not a worse one, but the
## player must know they are making the trade.
static func wanted(state_fov: float, motion_reduction: bool, scanning: bool) -> float:
	if scanning:
		return Tuning.camera.crowdscan_fov
	return Tuning.camera.fov_motion_reduced if motion_reduction else state_fov


## The look-sensitivity multiplier for this frame. `TUN-CAM-CROWDSCAN-SPEED`
## while scanning, 1.0 otherwise.
##
## **SLOWER LOOKING IS THE WHOLE FEATURE**, together with the narrower lens. It
## is what a scan grants instead of a reveal: precision, and the seconds it costs
## you to use it. Applied in `InputSampler`, so the scaled look reaches the pawn
## and the server as one number and a replay reproduces the pan exactly.
static func look_scale(scanning: bool) -> float:
	return Tuning.camera.crowdscan_speed if scanning else 1.0


## Advance the current FOV toward `target` at `TUN-CAM-FOV-BLEND-RATE`.
##
## Rate-limited rather than eased, and symmetric in both directions. Easing would
## make the lens lag differently on the way up than on the way down, and a
## warning channel that arrives late is one a player learns to distrust — the
## widening must start on the tick the speed does.
static func step(current: float, target: float, delta: float) -> float:
	return move_toward(current, target, Tuning.camera.fov_blend_rate * maxf(delta, 0.0))


## Seconds for the lens to cross the whole ladder, blend-walk to sprint. Not used
## by the rig; it exists so the budget is assertable, because "90 deg/s" only
## means something next to how far the lens ever has to travel.
static func full_sweep_seconds() -> float:
	var span := Tuning.camera.fov_sprint - Tuning.camera.fov_blend
	return span / maxf(Tuning.camera.fov_blend_rate, 0.001)


## Where the lens starts, and what an unregistered state gets. Stroll: the
## civilian default, and the rung a pawn spawns onto.
static func default_fov() -> float:
	return Tuning.camera.fov_stroll
