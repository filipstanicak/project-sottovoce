## **WHETHER A STUN PRESS LANDS, DECIDED AGAINST THE REWOUND WORLD.** TDD-10 §4,
## GDD-03 §10, ADR-0010, US-0061. PURE Core.
##
## The same split `KillRules` makes: every geometric question lives here, so
## `StunSystem` is left with the sequencing and the consequences.
##
## **THE RANGE IS THE MOST IMPORTANT NUMBER IN THE GAME AND IT IS NOT WRITTEN
## HERE.** `TUN-STUN-RANGE` 3.0 m exceeds `TUN-KILL-RANGE` 2.5 m — invariant
## §17.6, asserted in `TuningInvariants` rather than in this file, because a
## relationship enforced by the code that uses it is one a refactor can drop. A
## hunter who has closed to kill range has **already** entered stun range, so
## recklessness is punished by geometry before it is punished by scoring.
##
## **AND THE CONE IS TWICE THE KILL'S, BECAUSE THE PLAYER IS TURNING IN PANIC.**
## `TUN-STUN-FACING-CONE` 120° against `TUN-KILL-FACING-CONE` 60°. The hunter is
## aiming; the prey is spinning.
##
## **NOTHING HERE READS THE PURSUER'S YAW.** Stunning somebody who is facing away
## from you is fine — it is the hunter's own carelessness that put them in reach.
## The rule is enforced by there being no call rather than by a comment, and
## `test_stun_reads_one_yaw.gd` scans this file for exactly that.
class_name StunRules
extends RefCounted


## The furthest a stun may reach, after the rewind.
##
## **IT SHARES `TUN-KILL-VALIDATION-GRACE` RATHER THAN CLAIMING ITS OWN.** The
## grace absorbs quantisation, the interpolation endpoint and sub-tick timing —
## ADR-0010's list — and none of those is different for a stun. A second tunable
## for the same physical error would be one that gets retuned alone, and the day
## it drifted below the kill's the stun's range advantage would quietly narrow.
static func reach(t: CombatTuning) -> float:
	return t.stun_range + t.kill_validation_grace


## Is `at` inside the stunner's cone? `TUN-STUN-FACING-CONE` is the **total**
## width, so the test is against half of it.
static func within_cone(from: Vector3, yaw: float, at: Vector3, t: CombatTuning) -> bool:
	var toward := CompassMath.bearing_to(from, at)
	return absf(CompassMath.angle_between(yaw, toward)) <= deg_to_rad(t.stun_facing_cone) * 0.5


## Three-dimensional, exactly as `KillRules.in_reach` is and for the same reason:
## the strata are 3.5 m apart, and a horizontal reach would let a player on the
## street stun one standing on the roof above them.
static func in_reach(from: Vector3, at: Vector3, t: CombatTuning) -> bool:
	return from.distance_to(at) <= reach(t)


## **THE VERDICT.** `pursuer` is the peer who has been *announced* this player's
## contract, or `ContractCycle.NOBODY`; `others` is every other living player.
##
## Returns `[verdict, target_peer]`. The target is who the swing found — it is
## `NOBODY` when the press met empty air, and it is deliberately **not** used to
## tell the client anything (see `StunVerdict`).
static func resolve(
	world: RewoundWorld, stunner: int, pursuer: int, others: PackedInt32Array, t: CombatTuning
) -> Array:
	var here := world.position_of(stunner)
	if here == Vector3.INF:
		# The ring did not hold the stunner. Not a mistake the player made, so the
		# safe answer is the one that charges nothing.
		return [StunVerdict.V.BUSY, ContractCycle.NOBODY]
	var yaw := world.yaw_of(stunner)
	var target := _nearest_in_reach(world, here, yaw, others, t)
	if target == ContractCycle.NOBODY:
		return [_why_no_target(world, here, yaw, pursuer, t), ContractCycle.NOBODY]
	if pursuer == ContractCycle.NOBODY:
		return [StunVerdict.V.NO_PURSUER, target]
	if target != pursuer:
		return [StunVerdict.V.WRONG_TARGET, target]
	return [StunVerdict.V.ALLOWED, target]


## The nearest player inside both the range and the cone, or `NOBODY`.
##
## **NEAREST, NOT FIRST**, for `KillRules`' reason: iteration order over peers is
## join order, so taking the first match would decide a crowded swing by who
## happened to connect earlier.
static func _nearest_in_reach(
	world: RewoundWorld, here: Vector3, yaw: float, others: PackedInt32Array, t: CombatTuning
) -> int:
	var best := ContractCycle.NOBODY
	var best_distance := INF
	for peer: int in others:
		var at := world.position_of(peer)
		if at == Vector3.INF:
			continue
		if not in_reach(here, at, t) or not within_cone(here, yaw, at, t):
			continue
		var distance := CompassMath.distance_to(here, at)
		if distance < best_distance:
			best_distance = distance
			best = peer
	return best


## Nobody was in reach and in cone. Say *why the pursuer* was not, when that can
## be answered — the reason never reaches the client, but it reaches
## `TEL-STUN-REJECTED`, and "two metres short" and "swung at an empty street" are
## different mistakes for a balance pass to tell apart.
static func _why_no_target(
	world: RewoundWorld, here: Vector3, yaw: float, pursuer: int, t: CombatTuning
) -> StunVerdict.V:
	if pursuer == ContractCycle.NOBODY:
		return StunVerdict.V.NO_PURSUER
	var at := world.position_of(pursuer)
	if at == Vector3.INF:
		return StunVerdict.V.NO_TARGET
	if not in_reach(here, at, t):
		return StunVerdict.V.OUT_OF_RANGE
	if not within_cone(here, yaw, at, t):
		return StunVerdict.V.OUT_OF_CONE
	return StunVerdict.V.NO_TARGET
