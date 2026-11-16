## **WHAT A FIGURE DOES THAT IS NOT WALKING.** ADR-0026, US-0109. CLIENT ONLY. PURE.
##
## Climbing, striking, reeling, choking, falling. **None of these has to match a
## civilian's**, and ANIMATION_SPEC §1 says why: every one is reachable only after
## anonymity is already spent, so the tell is the point. They are poses rather
## than performances — a held shape that says what happened, eased into.
class_name FigureActs
extends RefCounted

## How long a strike takes from wind-up to reach, in seconds. Shorter than the
## kill's own lock, so the arm is out when the contact frame lands.
const STRIKE_SECONDS := 0.45
const FALL_SECONDS := 0.55


## Write `act`'s pose. `time` is seconds since it began; `phase` is the gait's.
static func pose(target: FigurePose, act: FigureMotion.Act, time: float, phase: float) -> void:
	match act:
		FigureMotion.Act.CLIMB:
			_climb(target, phase)
		FigureMotion.Act.AIRBORNE:
			_airborne(target)
		FigureMotion.Act.STRIKE:
			_strike(target, clampf(time / STRIKE_SECONDS, 0.0, 1.0))
		FigureMotion.Act.SHOVE:
			_shove(target, clampf(time / STRIKE_SECONDS, 0.0, 1.0))
		FigureMotion.Act.REEL:
			_reel(target, time, 1.0)
		FigureMotion.Act.STAGGER:
			_reel(target, time, 0.5)
		FigureMotion.Act.CHOKE:
			_choke(target, time)
		FigureMotion.Act.FALL:
			_fall(target, clampf(time / FALL_SECONDS, 0.0, 1.0))
		FigureMotion.Act.DASH:
			_dash(target)
		FigureMotion.Act.FLINCH:
			_flinch(target)
		FigureMotion.Act.GAWK:
			_gawk(target)


## Whether `act` keeps the legs walking under it.
static func keeps_the_gait(act: FigureMotion.Act) -> bool:
	return act == FigureMotion.Act.NONE or act == FigureMotion.Act.DASH


## Hand over hand up a wall, the opposite knee coming up with each reach.
static func _climb(target: FigurePose, phase: float) -> void:
	for side: int in 2:
		var p := phase + PI * float(side)
		target.put(FigurePose.SHOULDER_L + side, 2.5 + 0.45 * sin(p))
		target.put(FigurePose.ELBOW_L + side, 0.9 + 0.5 * cos(p))
		target.put(FigurePose.HIP_L + side, 0.75 - 0.5 * sin(p))
		target.put(FigurePose.KNEE_L + side, 1.25 - 0.5 * cos(p))
	target.put(FigurePose.SPINE_PITCH, 0.08)
	target.put(FigurePose.HEAD_PITCH, -0.3)


## Over a counter, off a ledge, across a gap: tucked, arms out for the landing.
static func _airborne(target: FigurePose) -> void:
	target.put(FigurePose.HIP_L, 0.75)
	target.put(FigurePose.HIP_R, 0.3)
	target.put(FigurePose.KNEE_L, 1.1)
	target.put(FigurePose.KNEE_R, 0.7)
	target.both(FigurePose.SHOULDER_L, 0.7)
	target.both(FigurePose.ARM_OUT_L, 0.5)
	target.both(FigurePose.ELBOW_L, 0.5)
	target.put(FigurePose.SPINE_PITCH, 0.22)


## The kill: the right arm drawn back, then driven out over a planted left foot.
static func _strike(target: FigurePose, t: float) -> void:
	var out := smoothstep(0.3, 0.75, t)
	target.put(FigurePose.SHOULDER_R, lerpf(-0.9, 1.45, out))
	target.put(FigurePose.ELBOW_R, lerpf(1.7, 0.12, out))
	target.put(FigurePose.SHOULDER_L, lerpf(0.5, -0.5, out))
	target.put(FigurePose.ELBOW_L, 1.0)
	target.put(FigurePose.HIP_L, 0.2 + 0.45 * out)
	target.put(FigurePose.KNEE_L, 0.25 + 0.3 * out)
	target.put(FigurePose.HIP_R, -0.35 * out)
	target.put(FigurePose.SPINE_PITCH, 0.1 + 0.25 * out)
	target.put(FigurePose.SPINE_YAW, lerpf(0.4, -0.35, out))
	target.put(FigurePose.HIPS_Y, -0.06 * out)


## The stun: both hands driven into the pursuer's chest.
static func _shove(target: FigurePose, t: float) -> void:
	var out := smoothstep(0.2, 0.6, t)
	target.both(FigurePose.SHOULDER_L, lerpf(0.4, 1.4, out))
	target.both(FigurePose.ELBOW_L, lerpf(1.9, 0.2, out))
	target.put(FigurePose.HIP_L, 0.35 * out)
	target.put(FigurePose.HIP_R, -0.25 * out)
	target.put(FigurePose.KNEE_L, 0.3 * out)
	target.put(FigurePose.SPINE_PITCH, 0.08 + 0.18 * out)


## Stunned or staggered: doubled over, swaying, hands hanging. `depth` scales it.
static func _reel(target: FigurePose, time: float, depth: float) -> void:
	target.put(FigurePose.SPINE_PITCH, 0.75 * depth)
	target.put(FigurePose.HEAD_PITCH, 0.3 * depth)
	target.both(FigurePose.SHOULDER_L, 0.55 * depth)
	target.both(FigurePose.ELBOW_L, 0.3)
	target.both(FigurePose.KNEE_L, 0.35 * depth)
	target.both(FigurePose.HIP_L, 0.2 * depth)
	target.put(FigurePose.HIPS_Y, -0.06 * depth)
	target.put(FigurePose.HIPS_X, 0.05 * depth * sin(time * 3.0))
	target.put(FigurePose.SPINE_ROLL, 0.1 * depth * sin(time * 2.3))


## In the cinder cloud: bent, hands over the face, shaken by each cough.
static func _choke(target: FigurePose, time: float) -> void:
	target.put(FigurePose.SPINE_PITCH, 0.5 + 0.14 * absf(sin(time * 7.0)))
	target.put(FigurePose.HEAD_PITCH, 0.3)
	target.both(FigurePose.SHOULDER_L, 1.1)
	target.both(FigurePose.ELBOW_L, 2.2)
	target.both(FigurePose.KNEE_L, 0.25)
	target.put(FigurePose.HIPS_Y, -0.04)


## Dead: onto the back, arms thrown wide, and left there.
static func _fall(target: FigurePose, t: float) -> void:
	var down := smoothstep(0.0, 1.0, t)
	target.put(FigurePose.ROOT_PITCH, -PI * 0.5 * down)
	target.put(FigurePose.ROOT_Y, 0.14 * down)
	target.both(FigurePose.ARM_OUT_L, 1.1 * down)
	target.both(FigurePose.ELBOW_L, 0.3)
	target.put(FigurePose.HIP_L, 0.12 * down)
	target.put(FigurePose.KNEE_L, 0.3 * down)
	target.put(FigurePose.HEAD_YAW, 0.5 * down)


## The lunge: thrown forward behind an outstretched arm. The legs keep running.
static func _dash(target: FigurePose) -> void:
	target.put(FigurePose.SPINE_PITCH, 0.5)
	target.put(FigurePose.HEAD_PITCH, -0.35)
	target.put(FigurePose.SHOULDER_R, 1.5)
	target.put(FigurePose.ELBOW_R, 0.1)
	target.put(FigurePose.SHOULDER_L, -0.8)
	target.put(FigurePose.ELBOW_L, 0.7)


## A civilian startled: back on the heels, hands up.
static func _flinch(target: FigurePose) -> void:
	target.put(FigurePose.SPINE_PITCH, -0.2)
	target.both(FigurePose.SHOULDER_L, 1.9)
	target.both(FigurePose.ELBOW_L, 1.9)
	target.both(FigurePose.ARM_OUT_L, 0.3)
	target.both(FigurePose.KNEE_L, 0.3)
	target.put(FigurePose.HIPS_Z, -0.08)


## A civilian staring at a body: craned forward, a hand to the mouth.
static func _gawk(target: FigurePose) -> void:
	target.put(FigurePose.SPINE_PITCH, 0.2)
	target.put(FigurePose.HEAD_PITCH, 0.2)
	target.put(FigurePose.SHOULDER_R, 1.0)
	target.put(FigurePose.ELBOW_R, 2.1)
	target.put(FigurePose.ELBOW_L, 0.2)
