## **ONE INPUT, SEVEN OUTCOMES, FIRST MATCH WINS.** GDD-02 §7.2, TDD-06 §4.2.
##
## The player never chooses *which* manoeuvre. They choose whether to move
## through the world athletically, and this decides how — from what the probes
## found, in an order that is normative and asserted.
##
## The order is the design, not an implementation detail. Every rung of it is a
## decision someone made and can be read back:
##
## | # | Case | Why it sits there |
## |---|---|---|
## | 1 | Ledge grab | Forgiveness first, always. Catching a ledge you are falling past beats all. |
## | 2 | Gap jump | Crossing a gap you are running at is unambiguous intent. |
## | 3 | Drop | No landing within range. |
## | 4 | Vault | **Before mantle**: a low wall you go *over* must not become one you climb *onto*. |
## | 5 | Mantle | |
## | 6 | Climb | **Last.** The most expensive option is never chosen when a cheaper one applies. |
## | 7 | Nothing | Input consumed, no animation. Silence, not a flail. |
##
## PURE and static. Given a `PawnContext` it reads `probe_result`, `grounded` and
## the forgiveness counters, and touches nothing else — so every case above is a
## unit test with a hand-filled struct and no world.
##
## **Seven cases, four states.** Gap jump and drop both enter `Drop`, vault and
## mantle both enter `Vault`, and each state branches internally on the numbers
## the probes left. `classify()` therefore exists beside `resolve()`: the ordering
## is what the design specifies, and a test that could only see the state name
## could not tell case 2 from case 3 at all.
class_name TraversalResolver
extends RefCounted

## The seven cases of §7.2, in priority order. `NONE` is case 7.
enum Case { NONE, LEDGE_GRAB, GAP_JUMP, DROP, VAULT, MANTLE, CLIMB }

## Case -> the state it enters. Two pairs collapse; see the class docstring.
const STATE_FOR: Dictionary = {
	Case.LEDGE_GRAB: PawnStateId.CLIMB,
	Case.GAP_JUMP: PawnStateId.DROP,
	Case.DROP: PawnStateId.DROP,
	Case.VAULT: PawnStateId.VAULT,
	Case.MANTLE: PawnStateId.VAULT,
	Case.CLIMB: PawnStateId.CLIMB,
}


## Which case applies right now. **NO SIDE EFFECTS** — it does not consume the
## buffered input, so a caller may ask twice, and a tell or an animation
## anticipation may ask without stealing the player's press.
static func classify(ctx: PawnContext) -> Case:
	var probe := ctx.probe_result
	if not probe.valid:
		# Nothing was measured this frame. Not "nothing is there".
		return Case.NONE
	if _is_ledge_grab(ctx, probe):
		return Case.LEDGE_GRAB
	if probe.at_edge():
		return (
			Case.GAP_JUMP if probe.gap_is_crossable(Tuning.movement.traverse_gap_max) else Case.DROP
		)
	if probe.waist_hit:
		var vault := _vault_or_mantle(probe)
		if vault != Case.NONE:
			return vault
	if _is_climb(probe):
		return Case.CLIMB
	return Case.NONE


## Case 1. Airborne, a ledge within `TUN-TRAVERSE-MAGNET-RADIUS` laterally, and
## the late window still open.
##
## `ledge_magnet_ticks` is what forgives pressing traverse AFTER you have passed
## the ledge — `TUN-TRAVERSE-MAGNET-WINDOW`, 0.25 s. Together with the 0.20 s
## early buffer that is a ~0.45 s window around every opportunity, which is
## enormous by action-game standards and correct: the player's attention belongs
## on the crowd, not on their own footwork.
static func _is_ledge_grab(ctx: PawnContext, probe: ProbeResult) -> bool:
	if ctx.grounded:
		return false
	if not probe.ledge_within(Tuning.movement.traverse_magnet_radius):
		return false
	return ctx.ledge_magnet_ticks > 0


## Cases 4 and 5. Vault first, so a low wall you can go over does not become one
## you climb onto — and a vault needs somewhere to land, or it is a vault into a
## wall (§7.2 case 4 requires `clear_beyond`).
static func _vault_or_mantle(probe: ProbeResult) -> Case:
	if probe.obstacle_top <= Tuning.movement.traverse_vault_max_height:
		return Case.VAULT if probe.clear_beyond else Case.NONE
	if probe.obstacle_top <= Tuning.movement.traverse_mantle_max_height:
		return Case.MANTLE
	return Case.NONE


## Case 6. A climbable face within one stratum transition.
static func _is_climb(probe: ProbeResult) -> bool:
	if not probe.chest_hit or not probe.surface_is_climbable:
		return false
	return probe.surface_height <= Tuning.movement.traverse_climb_max_height


## The state a traverse press enters, or `PawnState.STAY` for silence.
##
## **CONSUMING.** It spends the buffered input whatever the outcome, including
## case 7 — GDD-02 §7.2 says a failed traverse consumes the input and plays
## nothing. Leaving it buffered would fire the manoeuvre a moment later, at the
## next wall the player walked past, which is worse than doing nothing.
static func resolve(ctx: PawnContext) -> StringName:
	if not PawnInputBuffer.consume_traverse(ctx):
		return PawnState.STAY
	var case := classify(ctx)
	plan(ctx, case)
	return state_for(case)


## Commit the manoeuvre's geometry to `ctx`, once, at the instant of the press.
##
## **PLANNED ONCE AND NEVER RE-READ.** The probes refresh every physics frame, so
## a state that recomputed its target mid-manoeuvre would chase the wall it is
## currently crossing — and would chase it differently on the server than on the
## client's replay, because the two are a frame apart. Committing here is what
## makes the displacement identical on every peer, which is the whole premise of
## ANIMATION_SPEC §4's root-motion allowance.
static func plan(ctx: PawnContext, case: Case) -> void:
	ctx.traverse_case = case
	ctx.traverse_start = ctx.position
	ctx.traverse_target = ctx.position
	ctx.traverse_peak_y = ctx.position.y
	match case:
		Case.VAULT:
			_plan_vault(ctx)
		Case.MANTLE:
			_plan_mantle(ctx)
		Case.CLIMB:
			_plan_climb(ctx)
		Case.LEDGE_GRAB:
			_plan_ledge_grab(ctx)
		Case.GAP_JUMP:
			_plan_gap_jump(ctx)
		Case.DROP:
			_plan_drop(ctx)
		_:
			pass


## OVER it and down the far side, to the landing the probes measured. Not a guess
## at how thick the obstacle was: nothing measures that.
static func _plan_vault(ctx: PawnContext) -> void:
	var probe := ctx.probe_result
	var forward := ProbeLayout.forward(ctx.yaw)
	ctx.traverse_target = (
		ctx.position + forward * probe.beyond_distance + Vector3.DOWN * probe.beyond_drop
	)
	# Clear the top by the foot probe's height, so the pawn goes over the wall
	# rather than through it.
	ctx.traverse_peak_y = ctx.position.y + probe.obstacle_top + Tuning.movement.probe_height_foot


## ONTO it. The obstacle-top cast already stands one step past the face, which is
## where a mantle puts your feet. No arc: the target IS the top, so a straight
## rise lands on it.
static func _plan_mantle(ctx: PawnContext) -> void:
	var probe := ctx.probe_result
	var ahead := probe.distance + Tuning.movement.gap_probe_step
	ctx.traverse_target = (
		ctx.position + ProbeLayout.forward(ctx.yaw) * ahead + Vector3.UP * probe.obstacle_top
	)
	ctx.traverse_peak_y = ctx.traverse_target.y


## UP the façade to its top, and one step onto it. The distance decides how long
## the climb takes: `TUN-SPEED-CLIMB` is a speed, not a duration, so a 9 m face
## costs three times what a 3 m one does.
static func _plan_climb(ctx: PawnContext) -> void:
	var probe := ctx.probe_result
	var over := probe.distance + Tuning.movement.gap_probe_step
	ctx.traverse_target = (
		ctx.position + ProbeLayout.forward(ctx.yaw) * over + Vector3.UP * probe.surface_height
	)
	ctx.traverse_peak_y = ctx.traverse_target.y


## Sideways onto the ledge you were falling past, then up onto it. The lateral
## component is the whole point of the magnet radius.
static func _plan_ledge_grab(ctx: PawnContext) -> void:
	var probe := ctx.probe_result
	var side := ProbeLayout.right(ctx.yaw) * probe.ledge_lateral
	var reach := probe.distance if probe.distance > 0.0 else Tuning.movement.probe_length
	ctx.traverse_target = (
		ctx.position + side + ProbeLayout.forward(ctx.yaw) * reach + Vector3.UP * probe.ledge_height
	)
	ctx.traverse_peak_y = ctx.traverse_target.y


## Across. The landing is where the marching gap probe found ground.
static func _plan_gap_jump(ctx: PawnContext) -> void:
	var probe := ctx.probe_result
	ctx.traverse_target = (
		ctx.position
		+ ProbeLayout.forward(ctx.yaw) * probe.gap_distance
		+ Vector3.DOWN * _finite(probe.drop_height)
	)
	ctx.traverse_peak_y = ctx.position.y + _launch_apex()


## Straight down off the edge, one step out so the pawn clears the lip.
static func _plan_drop(ctx: PawnContext) -> void:
	var probe := ctx.probe_result
	ctx.traverse_target = (
		ctx.position
		+ ProbeLayout.forward(ctx.yaw) * Tuning.movement.gap_probe_ahead
		+ Vector3.DOWN * _finite(probe.drop_height)
	)
	ctx.traverse_peak_y = ctx.position.y


## `INF` means the probes found no floor at all. Falling forever is not a
## manoeuvre, so an unmeasured drop is treated as the deepest one the probes can
## see — the pawn lands somewhere rather than leaving the world.
static func _finite(drop: float) -> float:
	return Tuning.movement.gap_probe_depth if drop == INF else drop


## How high a gap jump rises above its launch, from `TUN-TRAVERSE-GAPJUMP-LAUNCH`
## and the pinned gravity. `v² / 2g`, which is the apex of a ballistic arc.
static func _launch_apex() -> float:
	var v := Tuning.movement.gapjump_launch
	return (v * v) / (2.0 * maxf(Tuning.gravity, 0.001))


## How long a gap jump is airborne: `2v / g`, the full up-and-down flight.
static func gapjump_flight_ticks() -> int:
	var seconds := 2.0 * Tuning.movement.gapjump_launch / maxf(Tuning.gravity, 0.001)
	return maxi(int(round(seconds * Tuning.net.client_input_rate)), 1)


## How long a fall of `height` metres takes, in `step()` ticks: `sqrt(2h/g)`.
##
## Derived rather than tuned. GDD-02 §6's cost table quotes ~0.9 s for a 4 m drop
## and ~1.1 s for a hard one, which is what gravity gives — the numbers in the
## design were read off the physics, so tuning them separately would let the two
## disagree.
static func fall_ticks(height: float) -> int:
	var h := maxf(height, 0.0)
	var seconds := sqrt(2.0 * h / maxf(Tuning.gravity, 0.001))
	return maxi(int(round(seconds * Tuning.net.client_input_rate)), 1)


## How long the committed manoeuvre lasts, in `step()` ticks.
##
## **ZERO FOR ANYTHING THAT IS NOT A VAULT OR A MANTLE.** Returning the vault
## duration for, say, `Case.NONE` would be a lie with a plausible value, and
## `VaultState` would hold a pawn motionless for half a second on a plan that
## does not exist. Zero makes it leave on the first tick instead.
static func duration_ticks(case: int) -> int:
	match case:
		Case.VAULT:
			return Tuning.step_ticks(&"TUN-TRAVERSE-VAULT-DURATION")
		Case.MANTLE:
			return Tuning.step_ticks(&"TUN-TRAVERSE-MANTLE-DURATION")
		_:
			return 0


static func state_for(case: Case) -> StringName:
	return STATE_FOR.get(case, PawnState.STAY)


## The yaw a gap jump should leave the pawn at.
##
## Auto-align, bounded by `TUN-TRAVERSE-GAP-ALIGN-ARC`: a player should not have
## to be square to a gap they can plainly see. Returns the pawn's own yaw
## unchanged whenever the probes found the far side straight ahead, so aiming
## correctly is never overridden by the assist.
static func aligned_yaw(ctx: PawnContext) -> float:
	var arc := deg_to_rad(Tuning.movement.gap_align_arc)
	return ctx.yaw + clampf(ctx.probe_result.gap_yaw_offset, -arc, arc)


## Advance the late-grab window. Called once per `step()`, from the machine,
## beside the action buffer — this changes the simulation, so it must run on the
## server and in the replay alike.
##
## `step_ticks`, not `ticks`: this counter advances at 60 Hz. The 30 Hz
## conversion would halve the window to 0.125 s (see `Tuning.step_ticks`).
static func tick_magnet(ctx: PawnContext) -> void:
	if ctx.probe_result.ledge_within(Tuning.movement.traverse_magnet_radius):
		ctx.ledge_magnet_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW")
	elif ctx.ledge_magnet_ticks > 0:
		ctx.ledge_magnet_ticks -= 1
