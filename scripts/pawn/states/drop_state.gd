## Drop, and the gap-jump arc. GDD-02 §3.1 and §6, TDD-06 §4.2 cases 2 and 3.
##
## **DROPPING DOWN IS THE CHEAP DIRECTION.** Zero suspicion, always — descending
## into the crowd is safer than ascending out of it, and §6.1's whole route
## economy depends on that asymmetry. The roofs are for *crossing*, and the
## correct play ends with a drop back into people.
##
## What a long fall costs is not anonymity but **helplessness**:
## `TUN-TRAVERSE-DROP-STAGGER` 0.8 s on any landing past
## `TUN-TRAVERSE-DROP-SAFE-HEIGHT` 4 m. Roof-to-balcony is 5 m and balcony-to-
## street 3.5 m, so upper transitions are free and only the final descent costs.
## **You can flee across the roofs cheaply and cannot rejoin the crowd cheaply**,
## which is exactly the shape the design wants: the escape is affordable, the
## return is a small skill check.
##
## The stagger is not a death sentence. It is a window during which you can be
## killed, and that is the point — panicking off a roof should be survivable and
## never free.
##
## A gap jump is the same state with an upward launch. It only exists on the roof
## stratum, so it always carries the roof toll anyway.
class_name DropState
extends PawnState


func id() -> StringName:
	return PawnStateId.DROP


## **NOTHING BELOW FATAL.** GDD-02 §3.1 says "No", where `Vault` says "Yes (to
## COMBAT+)" — and the difference is real: you cannot be stunned out of a
## freefall, because a stun is a thing done to someone who is standing up.
##
## Returning COMBAT here means the machine refuses `priority <= COMBAT` and
## admits only FATAL, matching how `Stunned` expresses the same rule.
func interrupt_priority() -> int:
	return PRIORITY_COMBAT


func is_interruptible(_ctx: PawnContext) -> bool:
	return false


func drives_position() -> bool:
	return true


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_run


func enter(ctx: PawnContext) -> void:
	super(ctx)
	ctx.velocity = Vector3.ZERO
	ctx.grounded = false


func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	var flight := flight_ticks(ctx)
	if ctx.state_timer_ticks < flight:
		var t := float(ctx.state_timer_ticks) / float(flight)
		ctx.position = position_at(ctx, t)
		return STAY

	# Landed. Hold for the stagger if the fall earned one.
	ctx.position = ctx.traverse_target
	ctx.grounded = true
	if ctx.state_timer_ticks >= flight + stagger_ticks(ctx):
		ctx.velocity = Vector3.ZERO
		return PawnStateId.IDLE
	return STAY


## Ticks in the air. A gap jump's flight is set by its launch speed; a plain
## drop's by how far it falls. Both come out of gravity rather than a tunable —
## GDD-02 §6's "~0.9 s" for a 4 m drop is what `sqrt(2h/g)` gives, so the design
## number was read off the physics and tuning it separately would let the two
## disagree.
static func flight_ticks(ctx: PawnContext) -> int:
	if ctx.traverse_case == TraversalResolver.Case.GAP_JUMP:
		return TraversalResolver.gapjump_flight_ticks()
	return TraversalResolver.fall_ticks(fall_height(ctx))


## How far this drop falls, in metres.
static func fall_height(ctx: PawnContext) -> float:
	return maxf(ctx.traverse_start.y - ctx.traverse_target.y, 0.0)


## True when the landing is hard enough to stagger.
##
## **STRICTLY PAST THE THRESHOLD.** Roof-to-balcony in MAP-VETRAIO is exactly
## 5.0 m and balcony-to-street exactly 3.5 m; the safe height is 4.0 m. A drop
## AT the threshold is clean, because the level design builds to that boundary
## and a `>=` would tax a transition the metrics deliberately made free.
static func is_hard_landing(ctx: PawnContext) -> bool:
	return fall_height(ctx) > Tuning.movement.traverse_drop_safe_height


static func stagger_ticks(ctx: PawnContext) -> int:
	if not is_hard_landing(ctx):
		return 0
	return Tuning.step_ticks(&"TUN-TRAVERSE-DROP-STAGGER")


## Where the pawn is at `t` through the flight, 0 to 1.
##
## Horizontal travel is linear; the height follows a ballistic curve. A gap jump
## rises to `traverse_peak_y` first and falls after, which is what makes it read
## as a jump rather than as a step off a kerb.
static func position_at(ctx: PawnContext, t: float) -> Vector3:
	var clamped := clampf(t, 0.0, 1.0)
	var flat := ctx.traverse_start.lerp(ctx.traverse_target, clamped)
	var rise := maxf(ctx.traverse_peak_y - ctx.traverse_start.y, 0.0)
	if rise <= 0.0:
		# A plain fall: no launch, so the descent accelerates from rest.
		var drop := ctx.traverse_start.y - ctx.traverse_target.y
		return Vector3(flat.x, ctx.traverse_start.y - drop * clamped * clamped, flat.z)
	# A launch: up and over. Zero at both ends, so the pawn lands on the plan.
	return Vector3(flat.x, flat.y + rise * sin(clamped * PI), flat.z)
