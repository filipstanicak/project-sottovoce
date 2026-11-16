## **HOW A FIGURE MOVES, AS ARITHMETIC.** ADR-0026, US-0109. CLIENT ONLY. PURE.
##
## ANIMATION_SPEC was written for two rigs and 195 clips, with four layers of
## enforcement to keep the clone's set identical to the player's. There is one rig
## here and no clip: a pose is a function of how fast the figure is moving, where
## it is, and what it is doing — and **nothing in that list says whether a player
## is behind it.** Parity is not enforced; there is nothing for it to diverge from.
##
## **THE STRIDE IS THE SPEC'S** (§2.2). A blend-walk cycle is 1.15 s and a stroll
## cycle 0.78 s, at the speeds those names have in the tuning; run and sprint take
## §3.1's 0.54 s and 0.44 s. Between them the cycle is interpolated, so a figure
## speeding up has no moment at which its gait snaps.
class_name FigureMotion
extends RefCounted

## What a figure is doing that its movement alone does not say.
enum Act {
	NONE,
	CLIMB,
	AIRBORNE,
	STRIKE,
	SHOVE,
	REEL,
	STAGGER,
	CHOKE,
	FALL,
	DASH,
	FLINCH,
	GAWK,
}

## How a figure holds itself when it is not going anywhere.
enum Posture { STAND, SIT, LEAN }

## ANIMATION_SPEC §2 and §3.1, in seconds a stride cycle.
const CYCLE_BLEND_WALK := 1.15
const CYCLE_STROLL := 0.78
const CYCLE_RUN := 0.54
const CYCLE_SPRINT := 0.44

## Below this a figure is standing, whatever its last sample said.
const STILL := 0.12


## Seconds one stride cycle takes at `speed`.
static func cycle_seconds(speed: float) -> float:
	var m := Tuning.movement
	if speed <= m.blend_walk:
		return CYCLE_BLEND_WALK
	if speed <= m.stroll:
		return remap(speed, m.blend_walk, m.stroll, CYCLE_BLEND_WALK, CYCLE_STROLL)
	if speed <= m.run:
		return remap(speed, m.stroll, m.run, CYCLE_STROLL, CYCLE_RUN)
	return remap(minf(speed, m.sprint), m.run, m.sprint, CYCLE_RUN, CYCLE_SPRINT)


## How far a stride cycle carries a figure at `speed`, in metres.
static func cycle_metres(speed: float) -> float:
	return maxf(speed, Tuning.movement.blend_walk * 0.5) * cycle_seconds(speed)


## 0 at a walk, 1 at a sprint: how much of a run is in the gait.
static func haste(speed: float) -> float:
	var m := Tuning.movement
	return clampf(inverse_lerp(m.stroll, m.sprint, speed), 0.0, 1.0)


## The walking and running cycle at `phase`, `stride` (0..1) of full reach.
static func gait(pose: FigurePose, phase: float, stride: float, run: float) -> void:
	var swing := lerpf(0.42, 0.85, run) * stride
	var flex := lerpf(0.85, 1.7, run) * stride
	var arms := lerpf(0.36, 0.95, run) * stride
	for side: int in 2:
		var p := phase + PI * float(side)
		pose.put(FigurePose.HIP_L + side, swing * sin(p) + 0.1 * run * stride)
		# The knee folds as the leg comes through, and gives a little under load.
		var fold := maxf(cos(p), 0.0)
		pose.put(FigurePose.KNEE_L + side, flex * fold * fold + 0.07 * stride)
		pose.put(FigurePose.SHOULDER_L + side, -arms * sin(p))
		pose.put(
			FigurePose.ELBOW_L + side, lerpf(0.22, 1.45, run) + 0.2 * arms * maxf(-sin(p), 0.0)
		)
		pose.put(FigurePose.ARM_OUT_L + side, 0.07)
	pose.put(FigurePose.HIPS_Y, -lerpf(0.02, 0.05, run) * stride * (0.5 + 0.5 * cos(phase * 2.0)))
	pose.put(FigurePose.HIPS_ROLL, 0.04 * stride * sin(phase))
	pose.put(FigurePose.HIPS_YAW, 0.09 * stride * sin(phase))
	pose.put(FigurePose.SPINE_YAW, -0.16 * stride * sin(phase))
	var lean := lerpf(0.03, 0.24, run) * stride
	pose.put(FigurePose.SPINE_PITCH, lean)
	pose.put(FigurePose.HEAD_PITCH, -lean * 0.6)


## Standing: breath, a slow shift of weight, a look round. `own` is the figure's
## own offset into all three, so a crowd does not breathe in step.
static func idle(pose: FigurePose, time: float, own: float) -> void:
	var shift := sin(time * 0.42 + own)
	pose.put(FigurePose.HIPS_X, 0.025 * shift)
	pose.put(FigurePose.HIPS_ROLL, 0.04 * shift)
	pose.put(FigurePose.SPINE_ROLL, -0.04 * shift)
	pose.put(FigurePose.KNEE_L, 0.12 * maxf(shift, 0.0))
	pose.put(FigurePose.KNEE_R, 0.12 * maxf(-shift, 0.0))
	pose.put(FigurePose.SPINE_PITCH, 0.015 * sin(time * 1.9 + own))
	pose.both(FigurePose.ELBOW_L, 0.16)
	pose.both(FigurePose.ARM_OUT_L, 0.07)
	look_round(pose, time, own)


## The head's slow wander, which a seated or leaning figure keeps.
static func look_round(pose: FigurePose, time: float, own: float) -> void:
	var interest := 0.5 + 0.5 * sin(time * 0.13 + own)
	pose.put(FigurePose.HEAD_YAW, 0.45 * sin(time * 0.31 + own * 2.0) * interest)


## Seated: thighs level at `seat` metres above the ground, `back` metres behind
## where the figure stands, hands in the lap.
static func sit(pose: FigurePose, drop: float, back: float) -> void:
	pose.put(FigurePose.HIPS_Y, -drop)
	pose.put(FigurePose.ROOT_Z, -back)
	pose.both(FigurePose.HIP_L, 1.5)
	pose.both(FigurePose.KNEE_L, 1.5)
	pose.both(FigurePose.SHOULDER_L, 0.12)
	pose.both(FigurePose.ELBOW_L, 0.9)
	pose.both(FigurePose.ARM_OUT_L, 0.05)
	pose.put(FigurePose.SPINE_PITCH, -0.04)


## Leaning on a counter: bent at the waist, forearms down on it, one knee loose.
static func lean(pose: FigurePose) -> void:
	pose.put(FigurePose.HIPS_Z, -0.1)
	pose.put(FigurePose.SPINE_PITCH, 0.42)
	pose.put(FigurePose.HEAD_PITCH, -0.25)
	pose.both(FigurePose.SHOULDER_L, 0.7)
	pose.both(FigurePose.ELBOW_L, 1.35)
	pose.both(FigurePose.ARM_OUT_L, 0.12)
	pose.put(FigurePose.KNEE_R, 0.25)
	pose.put(FigurePose.HIP_R, 0.12)
