## **`SYS-DETECTION`. WHAT EACH PLAYER SEES OF EACH OTHER PLAYER.** GDD-03 §2,
## TDD-07 §4, US-0055 and US-0056. SERVER ONLY.
##
## Registered at the `detection` stage, which `SystemOrder` puts **after**
## `suspicion` because the render state is computed from *tier*: a tick of lag
## there makes the silhouette disagree with the tier indicator, which is an
## information-channel defect in a game made of information channels.
##
## **THE MATRIX COSTS NO RAYCASTS AT ALL, AND THAT IS THE DESIGN RATHER THAN AN
## OPTIMISATION.** GDD-03 §2.1's rule is `tier × relationship` and nothing else —
## an Exposed player's outline is drawn *through* geometry (§2.3), so occlusion
## must not gate it. The raycasts TDD-07 §4.3 budgets for belong to the Compass
## lock and `SCORE-FOCUS`, which are later stories; `has_los()` is here and ready
## for them, and the early-out ladder is what keeps them from being thirty.
##
## **IT ALSO HOLDS THE SERVER HALF OF `SYS-COMPASS`.** TDD-07 §1's diagram makes
## the bearing and the lock steps 9 and 10 of *this* pass, and TDD-07's own header
## says so — the Compass is about the observer's contract, which is the same
## relationship the render state is computed from, read one tick later would be a
## cone pointing at where the contract was. `CompassMath` is pure and Core; what
## happens here is one reading per hunter into `ctx.compass`.
##
## **THE ONLY LINE-OF-SIGHT QUERY IN THE PROJECT.** `test_los_single_query.gd`
## refuses a second one anywhere under `scripts/systems/` or `scripts/net/`, so
## `SCORE-FOCUS`, the lock and Cinderfall occlusion cannot come to disagree about
## what "visible" means.
class_name DetectionSystem
extends GameSystem

## A lock filled and a reveal was granted. The client's copy rides the snapshot's
## `lock_fraction` and `portrait_revealed`, never this.
signal lock_completed(hunter: int, contract: int)

## **THE PREY'S ONLY WARNING.** US-0059. `bearing` is a *world* angle with the
## Compass wobble already applied and `bucket` is a `Quantise.BUCKET_STEP` step,
## so nothing downstream of here holds an exact metre or a camera-relative angle.
##
## **THERE IS NOWHERE IN THIS SIGNATURE TO PUT AN IDENTITY**, which is the rule
## rather than an omission: `test_prey_warning_signal_arity.gd` refuses one on the
## event bus and `test_warning_names_nobody.gd` refuses one on the wire. A persona
## here would collapse the crowd from seventy-eight candidates to one, for free,
## and leave a Compass lock with nothing to earn.
signal prey_warned(prey: int, bearing: float, bucket: int)

## Cinder clouds, which are the one thing that blocks sight and is not geometry.
## Nothing places one until `SYS-ABILITY`.
##
## **`MatchContext`'s OWN LIST, ADOPTED BY REFERENCE IN `setup()`** — US-0060 gave
## it a second reader in `SYS-KILL`, two stages later. Mirroring it would be the
## defect `announced_contracts` was moved onto the context to avoid: two copies of
## a volume list, one of which decides sight and the other of which decides
## whether a kill may start.
var cinderfall: CinderfallVolumes = null

## **THE LOCK ARC, THE REVEAL AND THE PORTRAIT.** US-0058. Pure and separable, so
## the progression can be exercised against any pattern of interruption without a
## district; this system supplies only the yes-or-no its conditions come to.
var lock := CompassLock.new()

## How many raycasts the last pass spent. **Zero today**, and the number is
## published rather than assumed because TDD-07 §4.3 budgets 2–6 against a naive
## 30 and a budget nobody measures is a budget nobody keeps.
var raycasts_last_tick: int = 0

## Ordered pairs the ladder actually looked at, for the same reason.
var pairs_considered: int = 0

## **THE RE-TRIGGER COOLDOWN, AND ONLY THAT.** US-0059. Pure and separable for the
## same reason `lock` is: the cooldown's one interesting property — that a new
## pursuer re-arms it — is exercisable without a district.
var warning := PreyWarning.new()

## Warnings sent this match. Cumulative, unlike `raycasts_last_tick`, because the
## question worth asking of it is *did recklessness ever cost anybody anything*.
var warnings_sent: int = 0

## Rewound queries refused. **A counter rather than only a log line**, because a
## caller that quietly received `false` for the rest of a match would look like a
## world with no line of sight in it, and this is the number that says why.
var rewinds_refused: int = 0

var _ctx: MatchContext
var _query := PhysicsRayQueryParameters3D.new()

## The tier a pursuer must reach to be warned about, resolved from
## `TUN-COMPASS-WARN-MIN-TIER` once a tick rather than compared as a scalar.
## **The tier carries hysteresis and the scalar does not**, and a warning that
## strobed across the boundary would be the one channel the design cannot afford
## to make unreadable.
var _warn_tier: int = SuspicionMath.Tier.NOTICED


func stage() -> StringName:
	return &"detection"


func setup(ctx: MatchContext) -> void:
	_ctx = ctx
	cinderfall = ctx.cinderfall
	# **`WORLD` ONLY, AND THE MASK IS THE RULE RATHER THAN A FILTER.** NPCs, other
	# players and corpses all sit on `PAWN`/`NPC`, so a mask of `WORLD` cannot see
	# them however the query is written. GDD-03 §9.2: if NPCs occluded sight, a
	# dense crowd would be *mechanically* opaque and picking a person out of it
	# would be replaced by a visibility calculation. The crowd must hide you by
	# being confusing, never by being solid.
	_query.collision_mask = 1
	_query.collide_with_areas = false
	_query.collide_with_bodies = true


## One pass over the ordered pairs. Thirty at six players.
func tick(ctx: MatchContext, _dt: float) -> void:
	cinderfall = ctx.cinderfall
	cinderfall.expire(ctx.tick)
	raycasts_last_tick = 0
	pairs_considered = 0
	_warn_tier = SuspicionMath.evaluate_tier(
		Tuning.compass.warn_min_tier, SuspicionMath.Tier.ANONYMOUS, Tuning.suspicion
	)
	ctx.render_states.clear()
	ctx.compass.clear()
	for observer: int in ctx.pawn_contexts.keys():
		_read_the_compass(observer, ctx)
		for subject: int in ctx.pawn_contexts.keys():
			if observer == subject:
				continue
			_resolve_pair(observer, subject, ctx)


## **THE EARLY-OUT LADDER, CHEAPEST FIRST** (TDD-07 §4.3). Most players are
## Anonymous most of the time, which is the game working — so the first rung
## removes about seventy per cent of the pairs for the cost of one comparison.
func _resolve_pair(observer: int, subject: int, ctx: MatchContext) -> void:
	var pawn := ctx.pawn_contexts[subject] as PawnContext
	if pawn == null or pawn.tier == SuspicionMath.Tier.ANONYMOUS:
		return
	var hunts := announced_contract_of(observer, ctx) == subject
	var hunted_by := announced_contract_of(subject, ctx) == observer
	if not hunts and not hunted_by:
		return
	pairs_considered += 1
	ctx.render_states.set_state(observer, subject, RenderState.of(pawn.tier, hunts, hunted_by))
	if hunted_by:
		_consider_warning(observer, subject, pawn, ctx)


## **THE PREY'S ONLY WARNING.** GDD-03 §9.1, US-0059. `prey` is the observer and
## `pursuer` the player hunting them — that is `hunted_by`'s direction, and getting
## it backwards would warn the hunter about their own victim.
##
## **THE TIER TEST IS EQUIVALENT TO `_resolve_pair`'s FIRST RUNG TODAY, AND IS
## KEPT ANYWAY.** Invariant 8 pins `TUN-COMPASS-WARN-MIN-TIER` equal to
## `TUN-SUSPICION-TIER-NOTICED`, so "at or above the warn floor" and "not
## Anonymous" are the same condition and no profile `Tuning.adopt()` accepts can
## separate them. **A planted `>= ANONYMOUS` here therefore changes nothing and
## no test goes red** — measured, not assumed, while falsifying US-0059's guards.
##
## It is not deleted, because the rung above is an **early-out for cost**: it
## exists to drop about seventy per cent of the pairs before anything expensive.
## Resting the warning's correctness on a performance optimisation means that
## widening the ladder for some future reason would start warning prey about
## Anonymous pursuers, silently, and that is the one thing GDD-03 §9.1 says a
## competent hunter must never trigger. Two cheap comparisons buy the decoupling.
##
## **AND THE RANGE IS 3D**, like `TUN-KILL-RANGE` and unlike the suspicion radius:
## a pursuer on the roof stratum 3.5 m above is further away than their footprint
## suggests, and the warning is about how soon they can reach you.
func _consider_warning(prey: int, pursuer: int, them: PawnContext, ctx: MatchContext) -> void:
	var here := ctx.pawn_contexts.get(prey) as PawnContext
	if here == null:
		return
	var t := Tuning.compass
	var metres := CompassMath.distance_to(here.position, them.position)
	var within := metres <= t.warn_radius
	if not warning.consider(prey, pursuer, within, them.tier >= _warn_tier, ctx.tick):
		return
	warnings_sent += 1
	var bearing := CompassMath.shown_bearing(here.position, them.position, pursuer, ctx.tick, t)
	prey_warned.emit(prey, bearing, Quantise.distance_to_bucket(metres))


## **ONE COMPASS READING, FOR THE CONTRACT THIS HUNTER HAS BEEN TOLD ABOUT.**
## GDD-03 §8, US-0057.
##
## A hunter with no announced contract gets **no entry at all**, which the board
## reports as `NO_CONTRACT` rather than as a bearing of zero — a Compass pointing
## due +Z at nothing is worse than one that is plainly off, because a player would
## follow it.
##
## **THE BEARING IS WORLD, NOT CAMERA-RELATIVE.** The client knows its own yaw
## exactly and rotates the arc every rendered frame; a camera-relative bearing
## computed here would lag the mouse by the round trip on the one HUD element that
## has to track the player's head. What the server owns is the **wobble**, because
## that is gameplay — two players standing together must be lied to identically or
## they could average the lie away.
##
## **AND THE DISTANCE IS A BUCKET BEFORE IT LEAVES THIS FUNCTION**, so no caller
## downstream ever holds the exact one. GDD-03 §8.5: the hunter is told *nearer*,
## never *how far*.
func _read_the_compass(hunter: int, ctx: MatchContext) -> void:
	var contract := announced_contract_of(hunter, ctx)
	if contract == ContractCycle.NOBODY:
		return
	var here := ctx.pawn_contexts.get(hunter) as PawnContext
	var there := ctx.pawn_contexts.get(contract) as PawnContext
	if here == null or there == null:
		return
	var t := Tuning.compass
	var bearing := CompassMath.shown_bearing(here.position, there.position, contract, ctx.tick, t)
	var metres := CompassMath.distance_to(here.position, there.position)
	ctx.compass.set_reading(hunter, bearing, Quantise.distance_to_bucket(metres))
	_advance_the_lock(hunter, contract, here, there, metres, ctx)


## **CONE, RANGE, LINE OF SIGHT - CHEAPEST FIRST.** GDD-03 §8.4, TDD-07 §4.5.
##
## This is `has_los()`'s **first caller**. The raycast is last on purpose: the cone
## is one angle comparison and the range is a number already computed for the
## bearing, so a hunter looking the wrong way costs nothing. TDD-07 §4.3's 2-6
## raycasts a tick is that ladder, and `raycasts_last_tick` is what says whether it
## holds.
##
## **`PASV-COLDREAD` IS NOT READ, BECAUSE THERE IS NOWHERE TO READ IT FROM.**
## `NET-C2S-LOADOUT` is unbuilt and `PawnContext` has no passives field - the same
## blocker as `PASV-STILLNESS` in `SYS-SUSPICION`. `CompassLock` takes the flag as
## an argument and is tested both ways, so the day a loadout exists this is one
## call site rather than a rule to re-derive.
func _advance_the_lock(
	hunter: int,
	contract: int,
	here: PawnContext,
	there: PawnContext,
	metres: float,
	ctx: MatchContext
) -> void:
	var t := Tuning.compass
	var can_lock := metres <= t.lock_range and _within_facing_cone(here, there.position, t)
	if can_lock and t.lock_requires_los:
		can_lock = has_los(sight_point(here.position), sight_point(there.position))
	if lock.advance(hunter, contract, can_lock, MatchContext.net_dt(), false):
		lock_completed.emit(hunter, contract)
	ctx.compass.set_lock(hunter, lock.fraction_of(hunter), lock.portrait_revealed(hunter, contract))


## Is `at` inside the hunter's own facing cone? `TUN-COMPASS-LOCK-CONE` is the
## **total** width, so the test is against half of it.
##
## **THE HUNTER'S YAW, NOT THE COMPASS BEARING.** The bearing carries
## `TUN-COMPASS-CONE-WOBBLE`'s lie; the lock must be gated on where the player is
## actually looking, or a hunter aiming at the drifted cone would fail to lock a
## contract standing exactly where they are pointing.
func _within_facing_cone(here: PawnContext, at: Vector3, t: CompassTuning) -> bool:
	var toward := CompassMath.bearing_to(here.position, at)
	return absf(CompassMath.angle_between(here.yaw, toward)) <= deg_to_rad(t.lock_cone) * 0.5


## Who `peer` has been **told** they are hunting.
##
## **THE ANNOUNCED CONTRACT, NEVER THE GRAPH'S.** `SYS-CONTRACT` repairs the cycle
## in the tick a death resolves and holds the *announcement* for
## `TUN-CONTRACT-REASSIGN-DELAY`; rendering from the graph would put a tint on a
## player the hunter has not been given yet, so the silhouette would arrive before
## the Compass and the breath would be worth nothing.
func announced_contract_of(peer: int, ctx: MatchContext) -> int:
	return int(ctx.announced_contracts.get(peer, ContractCycle.NOBODY))


## **THE ONLY LINE-OF-SIGHT QUERY IN THE PROJECT.** TDD-07 §4.2.
##
## Blocked by world geometry and by active Cinderfall volumes. **Not blocked by
## NPCs, other players or corpses** — that is the mask, above, and it is why this
## cannot be got wrong by a caller.
##
## `at_tick >= 0` is the rewound form for kill and stun validation (ADR-0010). It
## is **not implemented and must not be faked**: the geometry does not move, so a
## rewound query against the world alone would answer the same as a current one
## and look correct — while the *players* it is really about would be at today's
## positions. `RewoundWorld` carries those and `SYS-KILL` (US-0060) is what pairs
## the two. Until then the argument is refused rather than ignored.
func has_los(from: Vector3, to: Vector3, at_tick: int = -1) -> bool:
	if at_tick >= 0:
		rewinds_refused += 1
		# **A WARNING RATHER THAN AN ERROR**, because nothing calls this yet: it is a
		# request for something unbuilt, not a failure of something built. The counter
		# above is what a caller notices; the line is what a reader does.
		Log.warn("has_los: rewound line of sight is SYS-KILL's, US-0060", &"net")
		return false
	# **CHECKED BEFORE THE RAYCAST**, because it is arithmetic against a list that
	# is almost always empty and the raycast is not.
	if cinderfall != null and cinderfall.blocks(from, to, _now()):
		return false
	return _clear_of_geometry(from, to)


## The raycast, counted. Separate so `has_los`'s early-outs stay readable and so
## the count cannot drift from the casts.
func _clear_of_geometry(from: Vector3, to: Vector3) -> bool:
	# **`GameSystem extends Node`, SO THERE IS NO `get_world_3d()` HERE.** That is
	# `Node3D`'s, and a system is deliberately not one — it decides outcomes and
	# owns no transform. The viewport's world is the same one the map's collision
	# is in, and it is null in a context with no tree, where "nothing blocks" is
	# the honest answer.
	var viewport := get_viewport()
	var world := viewport.find_world_3d() if viewport != null else null
	if world == null:
		return true
	_query.from = from
	_query.to = to
	raycasts_last_tick += 1
	return world.direct_space_state.intersect_ray(_query).is_empty()


## Where a line of sight starts and ends on a pawn.
##
## **ONE HEIGHT FOR BOTH ENDS**, which resolves TDD-07's own disagreement: §4.5's
## sketch reads `has_los(hunter.eye_position(), target.center_position())` while
## §9 question 3 commits to "a single centre-to-centre ray" for MVP. Two heights
## make the query asymmetric — A can see B while B cannot see A — and every
## consumer here is a mutual relationship.
##
## **DERIVED, NOT DECLARED.** `TUN-TRAVERSE-PROBE-HEIGHT-CHEST` is already the
## height this project treats as a body's forward-facing mass; a second constant
## for the same thing is one that gets retuned alone.
static func sight_point(at: Vector3) -> Vector3:
	return at + Vector3(0.0, Tuning.movement.probe_height_chest, 0.0)


## The tick the present-tense queries are asked about. Zero with no context,
## which is what a unit test that never stood one up gets.
func _now() -> int:
	return 0 if _ctx == null else _ctx.tick


func teardown() -> void:
	if cinderfall != null:
		cinderfall.clear()
	lock.clear()
	warning.clear()
	if _ctx != null:
		_ctx.render_states.clear()
		_ctx.compass.clear()
