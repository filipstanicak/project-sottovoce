## Vault AND mantle. GDD-02 §3.1, §6, TDD-06 §4.2 case 5.
##
## One state, branching internally on `ctx.traverse_case`, because the two are
## the same manoeuvre against different heights: get your hands on the top of
## something and put yourself on the other side of it. What differs is the
## duration and — the part that matters — **what it costs**.
##
## **A VAULT IS FREE.** Zero suspicion, the only athletic move in the game that
## costs nothing, and the backbone of ground-level route-finding. That is
## deliberate: patience has to be the strongest strategy (design law 4), and a
## patient player needs *options* at civilian speed or patience is only ever
## waiting. A district full of vaultable furniture is a district where the
## careful player has routes the reckless one never looks for.
##
## **A MANTLE IS NOT.** It costs `TUN-SUSPICION-GAIN-CLIMB` for its whole
## duration, because hauling yourself onto a two-metre wall is visibly athletic
## and a civilian does not do it. The 1.1 m boundary between them is where "a
## thing you could hop" becomes "a thing you climb".
##
## Chained vaults are geometry-limited. Watch `TEL-MEAN-SPEED` at M6 in case
## vault-chaining becomes a dominant travel mode; if it does, the answer is
## level design, not a suspicion cost on the vault.
class_name VaultState
extends PawnState


func id() -> StringName:
	return PawnStateId.VAULT


## COMBAT AND ABOVE ONLY. `is_interruptible()` false with a NORMAL priority means
## the machine refuses `priority <= NORMAL` and admits COMBAT — which is exactly
## GDD-02 §3.1's "Yes (to COMBAT+)". You can be killed or stunned mid-vault; you
## cannot change your mind about the wall.
func interrupt_priority() -> int:
	return PRIORITY_NORMAL


func is_interruptible(_ctx: PawnContext) -> bool:
	return false


## The plan owns the position for the whole manoeuvre.
func drives_position() -> bool:
	return true


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


## Freeze the velocity. The manoeuvre is a fixed displacement against static
## geometry, not an integration — carrying the approach speed into it would land
## the pawn somewhere the plan did not choose.
func enter(ctx: PawnContext) -> void:
	super(ctx)
	ctx.velocity = Vector3.ZERO


func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	var ticks := TraversalResolver.duration_ticks(ctx.traverse_case)
	if ticks <= 0 or ctx.state_timer_ticks >= ticks:
		ctx.position = ctx.traverse_target
		ctx.velocity = Vector3.ZERO
		return PawnStateId.IDLE

	# Interpolated along the committed plan, in TICKS, so the server and the
	# client's replay pass through the identical positions. The animation is
	# matched to this rather than the reverse — see ANIMATION_SPEC §4.
	var t := float(ctx.state_timer_ticks) / float(ticks)
	ctx.position = position_at(ctx, t)
	return STAY


## Where the pawn is at `t` through the manoeuvre, 0 to 1.
##
## Horizontal travel is linear; the height arcs over `traverse_peak_y`. A
## straight lerp would take a vault THROUGH the wall it is crossing, which is
## wrong in the simulation and not merely in the render — the simulation is what
## decides whether the pawn ends up on the far side.
##
## Static and pure, so the whole trajectory is a unit test rather than something
## only visible by watching it.
static func position_at(ctx: PawnContext, t: float) -> Vector3:
	var clamped := clampf(t, 0.0, 1.0)
	var flat := ctx.traverse_start.lerp(ctx.traverse_target, clamped)
	var line_y := flat.y
	# Half-sine: zero at both ends, so the pawn arrives exactly on the plan and
	# leaves exactly from where it stood.
	var rise := maxf(ctx.traverse_peak_y - maxf(ctx.traverse_start.y, ctx.traverse_target.y), 0.0)
	return Vector3(flat.x, line_y + rise * sin(clamped * PI), flat.z)
