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

## Cinder clouds, which are the one thing that blocks sight and is not geometry.
## Nothing places one until `SYS-ABILITY`.
var cinderfall := CinderfallVolumes.new()

## How many raycasts the last pass spent. **Zero today**, and the number is
## published rather than assumed because TDD-07 §4.3 budgets 2–6 against a naive
## 30 and a budget nobody measures is a budget nobody keeps.
var raycasts_last_tick: int = 0

## Ordered pairs the ladder actually looked at, for the same reason.
var pairs_considered: int = 0

## Rewound queries refused. **A counter rather than only a log line**, because a
## caller that quietly received `false` for the rest of a match would look like a
## world with no line of sight in it, and this is the number that says why.
var rewinds_refused: int = 0

var _ctx: MatchContext
var _query := PhysicsRayQueryParameters3D.new()


func stage() -> StringName:
	return &"detection"


func setup(ctx: MatchContext) -> void:
	_ctx = ctx
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
	cinderfall.expire(ctx.tick)
	raycasts_last_tick = 0
	pairs_considered = 0
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
	if cinderfall.blocks(from, to):
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


func teardown() -> void:
	cinderfall.clear()
	if _ctx != null:
		_ctx.render_states.clear()
		_ctx.compass.clear()
