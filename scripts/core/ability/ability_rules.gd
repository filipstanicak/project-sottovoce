## **THE FIVE VALIDATIONS AND THE AIM CLAMP, AS PURE FUNCTIONS.** TDD-09 §1.1,
## US-0066. PURE.
##
## Every one is server-side, and the request message carries **no outcome** — only
## a slot and an aim. That is never-do #2 at the doorway: there is nothing in
## `NET-C2S-ABILITY-REQUEST` for a client to lie about except where it was
## pointing, and the answer to that is a clamp rather than a refusal.
##
## Facts in, verdict out. The system that owns the cooldown table asks; nothing
## here reads a clock, a context or a world.
class_name AbilityRules
extends RefCounted

## Pawn states in which no ability may start. **A denylist rather than an
## allowlist, and the reason is that the list of *legal* states is every other one
## — walking, running, climbing, vaulting, blending, falling.** An allowlist would
## have to be extended by every future locomotion state, and forgetting would make
## an ability silently unusable in a state nobody thought about.
const FORBIDDEN: Array[StringName] = [
	PawnStateId.STUNNED,
	PawnStateId.STUN_ANIM,
	PawnStateId.DEAD,
	PawnStateId.RESPAWNING,
	PawnStateId.KILL_ANIM,
]


## Validations 1 to 4, in TDD-09 §1.1's order — **cheapest first, and the order is
## also the order a player would want to be told about.** "You do not have that"
## before "not yet", and both before anything about where you were standing.
static func check(
	equipped: bool, tick: int, ready_at: int, global_ready_at: int, state: StringName
) -> AbilityDenial.Why:
	if not equipped:
		return AbilityDenial.Why.NOT_EQUIPPED
	if tick < ready_at:
		return AbilityDenial.Why.ON_COOLDOWN
	if tick < global_ready_at:
		return AbilityDenial.Why.GLOBAL_COOLDOWN
	if state in FORBIDDEN:
		return AbilityDenial.Why.ILLEGAL_STATE
	return AbilityDenial.Why.NONE


## Validation 5. **Clamped, never refused** — see `AimData`.
static func aim(origin: Vector3, direction: Vector3, facing: Vector3, reach: float) -> AimData:
	var data := AimData.new()
	data.origin = origin
	data.reach = maxf(reach, 0.0)
	data.direction = _usable(direction, facing)
	# **THE REQUESTED DISTANCE IS THE VECTOR'S LENGTH, NOT A FIELD.** The client
	# sends an origin and a direction; how far it meant is how long that direction
	# was. A separate distance field would be a second thing to validate and a
	# second thing to disagree with itself.
	var wanted := direction.length()
	data.clamped = wanted > data.reach
	data.point = data.origin + data.direction * minf(wanted, data.reach)
	return data


## **A CLIENT CAN SEND ZERO, NaN, OR A VECTOR OF LENGTH 400.** Normalising in one
## place is what stops four effects each writing their own guard and one of them
## forgetting. An unusable direction falls back to the caster's own facing, which
## is the least surprising thing a mis-sent cast can do.
static func _usable(direction: Vector3, facing: Vector3) -> Vector3:
	if not direction.is_finite() or direction.length_squared() < 0.000001:
		return facing.normalized() if facing.length_squared() > 0.0 else Vector3.FORWARD
	return direction.normalized()


## How far this ability's aim may reach. **`AbilityData` is one class holding four
## abilities' fields**, so each populates only its own and the non-zero one is this
## ability's reach: Cinderfall throws, Lunge dashes, Second Face acts on the self
## and reaches nowhere. That is the same property `test_tunables_match_the_document`
## already relies on, and it is why there is no single `aim_range` field to read.
static func reach_of(data: AbilityData) -> float:
	if data == null:
		return 0.0
	if data.throw_range > 0.0:
		return data.throw_range
	return maxf(data.distance, 0.0)
