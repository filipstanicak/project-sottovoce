## **WHETHER A KILL PRESS LANDS, DECIDED AGAINST THE REWOUND WORLD.** TDD-10 §3,
## ADR-0010, GDD-03, US-0060. PURE Core.
##
## Every geometric question a kill asks lives here, so `KillSystem` is left with
## the sequencing and the consequences. That split is the same one
## `ContractCycle`/`ContractSystem` and `CompassLock`/`SYS-DETECTION` make, and
## for the same reason: a rule that can only be exercised by standing a district
## up is a rule nobody writes the awkward cases for.
##
## **NOTHING HERE READS THE VICTIM'S YAW, AND THAT IS ASM-0010 EXPRESSED AS AN
## ABSENCE.** `TUN-KILL-FACING-CONE` constrains the *killer* only: killing someone
## facing away from you is the intended patient play, not an exploit. A rule
## enforced by there being no call to `yaw_of` for the victim survives a
## refactor; a rule enforced by a comment does not. `test_kill_facing_cone.gd`
## scans this file for exactly that.
##
## **AND IT MEASURES THE REWOUND WORLD, NEVER `MatchContext`.** The signature
## takes a `RewoundWorld` and no context at all, so there is no way to write the
## present-tense version of any of these checks — which is the single mistake
## ADR-0010 exists to prevent.
class_name KillRules
extends RefCounted


## The furthest a kill may reach, after the rewind. `TUN-KILL-RANGE` plus
## `TUN-KILL-VALIDATION-GRACE`.
##
## **THE GRACE IS ERROR ABSORPTION, NOT A RANGE EXTENSION**, and it is added here
## rather than at the call site so nothing can validate against the bare range by
## forgetting it. It absorbs 1 cm of quantisation, the interpolation endpoint and
## sub-tick timing — ADR-0010's own list.
static func reach(t: CombatTuning) -> float:
	return t.kill_range + t.kill_validation_grace


## Is `at` inside the killer's cone? `TUN-KILL-FACING-CONE` is the **total** width,
## so the test is against half of it.
##
## Read as a half-width the cone would be twice as forgiving, which is the mistake
## that makes killing somebody standing beside you work — and every other
## assertion in this file would still pass.
static func within_cone(from: Vector3, yaw: float, at: Vector3, t: CombatTuning) -> bool:
	var toward := CompassMath.bearing_to(from, at)
	return absf(CompassMath.angle_between(yaw, toward)) <= deg_to_rad(t.kill_facing_cone) * 0.5


## **THE RANGE IS THE STRAIGHT LINE AND THE CONE IS HORIZONTAL, AND THEY ARE
## DIFFERENT QUESTIONS.** "Can I reach you" is a distance; "am I facing you" is a
## bearing, and this game has no aim pitch to put in a cone.
##
## Measured in three dimensions on purpose, unlike the Compass beside it. A
## horizontal reach would make a player standing under a roof killable by the one
## standing on it: the strata are 3.5 m apart, so a purely horizontal test would
## put the whole stratum above you inside `TUN-KILL-RANGE` at zero cost. This is
## a melee kill at conversational distance, and the arm has to get there.
static func in_reach(from: Vector3, at: Vector3, t: CombatTuning) -> bool:
	return from.distance_to(at) <= reach(t)


## **THE VERDICT.** `contract` is the killer's *announced* contract, or
## `ContractCycle.NOBODY`; `others` is every other living player's peer id.
##
## Returns `[verdict, target_peer]`. The target is the peer the whiff was aimed
## at — `ContractCycle.NOBODY` when the press found nobody at all.
static func resolve(
	world: RewoundWorld, killer: int, contract: int, others: PackedInt32Array, t: CombatTuning
) -> Array:
	var here := world.position_of(killer)
	if here == Vector3.INF:
		# The killer was not in the rewound world at all. Not a rejection the
		# player caused: it means the ring did not hold them, and the safe answer
		# is the one that charges nothing.
		return [KillVerdict.V.BUSY, ContractCycle.NOBODY]
	var yaw := world.yaw_of(killer)
	var target := _nearest_in_reach(world, here, yaw, others, t)
	if target == ContractCycle.NOBODY:
		return [_why_no_target(world, here, yaw, contract, t), ContractCycle.NOBODY]
	if contract == ContractCycle.NOBODY:
		return [KillVerdict.V.NO_CONTRACT, target]
	if target != contract:
		return [KillVerdict.V.WRONG_TARGET, target]
	return [KillVerdict.V.ALLOWED, target]


## The nearest player inside both the range and the cone, or `NOBODY`.
##
## **NEAREST, NOT FIRST.** Iteration order over peers is join order, so taking the
## first match would hand a player standing between you and your contract the
## right to absorb the press only when they happened to join earlier.
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


## Nobody was in reach and in cone. Say *why the contract* was not, when that can
## be answered, because "your contract was two metres too far" and "you pressed
## kill at an empty street" are different mistakes and the whiff is the only
## feedback either one gets.
static func _why_no_target(
	world: RewoundWorld, here: Vector3, yaw: float, contract: int, t: CombatTuning
) -> KillVerdict.V:
	if contract == ContractCycle.NOBODY:
		return KillVerdict.V.NO_CONTRACT
	var at := world.position_of(contract)
	if at == Vector3.INF:
		return KillVerdict.V.NO_TARGET
	if not in_reach(here, at, t):
		return KillVerdict.V.OUT_OF_RANGE
	if not within_cone(here, yaw, at, t):
		return KillVerdict.V.OUT_OF_CONE
	return KillVerdict.V.NO_TARGET
