## WHERE THE PROBES GO. GDD-02 §7.1, TDD-06 §4.1.
##
## Pure: every function here is arithmetic on a position, a facing and a handful
## of tunables. It is separated from `TraversalProbes` — which owns the actual
## raycasts — because the geometry is the part that can be wrong in a way no
## playtest would name, and the part a unit test can reach without a world.
##
## Casting rays needs a physics space. Deciding *where* to cast them does not,
## and mixing the two would make the second untestable along with the first.
##
## **NOT A LITERAL ANYWHERE.** Three origin heights, a reach, a gap-probe start,
## depth and step: seven numbers, seven `TUN-` IDs. A probe layout is gameplay —
## move the waist probe 10 cm and a wall that vaulted now mantles.
class_name ProbeLayout
extends RefCounted

## The three forward probes, in resolution priority order (GDD-02 §7.2 reads
## CHEST for climb, WAIST for vault/mantle, FOOT for edges).
enum Probe { CHEST, WAIST, FOOT }
## cos(60°). A face is climbable when it leans no more than 30° off vertical.
## Not a tunable: it is the definition of "wall rather than slope", and the level
## design contract (GDD-02 §7.4) builds façades vertical and ramps shallow, so
## nothing in the map sits near this boundary for it to arbitrate.
const _CLIMBABLE_MAX_UP_DOT: float = 0.5


## Unit vector the pawn is facing, on the ground plane. Yaw 0 faces +Z, matching
## `LocomotionState._is_backpedalling` and `InputCommand.move`.
static func forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## Height above the pawn's feet at which `probe` starts.
static func origin_height(probe: Probe) -> float:
	match probe:
		Probe.CHEST:
			return Tuning.movement.probe_height_chest
		Probe.WAIST:
			return Tuning.movement.probe_height_waist
		_:
			return Tuning.movement.probe_height_foot


## World-space start of `probe`, given the pawn's feet position.
static func origin(feet: Vector3, probe: Probe) -> Vector3:
	return feet + Vector3.UP * origin_height(probe)


## World-space end of `probe`. Reach is longer than the pawn's 0.35 m radius so
## intent is detected *before* collision — a probe that only fired on contact
## would resolve a vault the frame after the player already stopped.
static func target(feet: Vector3, yaw: float, probe: Probe) -> Vector3:
	return origin(feet, probe) + forward(yaw) * Tuning.movement.probe_length


## The down-cast that looks for the top of an obstacle the waist probe hit.
##
## Starts at `TUN-TRAVERSE-MANTLE-MAX-HEIGHT` — the tallest thing that can still
## be an obstacle top rather than a climb — and one step *beyond* the hit, so it
## lands on the obstacle's upper surface rather than on its near face.
static func obstacle_top_origin(feet: Vector3, yaw: float, hit_distance: float) -> Vector3:
	var ahead := hit_distance + Tuning.movement.gap_probe_step
	var top := Tuning.movement.traverse_mantle_max_height
	return feet + forward(yaw) * ahead + Vector3.UP * top


## The down-cast that measures how tall a climbable façade is.
##
## Starts at `TUN-TRAVERSE-CLIMB-MAX-HEIGHT` — the ceiling §7.2 case 6 compares
## against — rather than at mantle height, because a façade is by definition
## taller than anything a mantle can reach, and a cast that began inside it would
## pass straight through and measure the floor.
static func climb_top_origin(feet: Vector3, yaw: float, hit_distance: float) -> Vector3:
	var ahead := hit_distance + Tuning.movement.gap_probe_step
	return feet + forward(yaw) * ahead + Vector3.UP * Tuning.movement.traverse_climb_max_height


## The down-cast that asks whether a vault has anywhere to land. One further step
## beyond the obstacle top, because landing ON the obstacle is a mantle.
static func clear_beyond_origin(feet: Vector3, yaw: float, hit_distance: float) -> Vector3:
	var ahead := hit_distance + Tuning.movement.gap_probe_step * 2.0
	var top := Tuning.movement.traverse_mantle_max_height
	return feet + forward(yaw) * ahead + Vector3.UP * top


## Horizontal offsets at which the gap probes are cast, marching from
## `TUN-TRAVERSE-GAP-PROBE-AHEAD` out to `TUN-TRAVERSE-GAP-MAX`.
##
## The FIRST entry answers "is there ground immediately ahead" — the edge test.
## The rest look for a landing, and the first of those that finds ground is the
## far side. A single probe could only ever say "no ground right here", which
## distinguishes nothing: every gap and every drop looks identical at 0.6 m.
static func gap_offsets() -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	var step := maxf(Tuning.movement.gap_probe_step, 0.05)
	var offset := Tuning.movement.gap_probe_ahead
	var limit := Tuning.movement.traverse_gap_max
	while offset <= limit + step * 0.5:
		out.append(offset)
		offset += step
	return out


## World-space start of the gap probe at `offset` metres ahead. Raised by the
## foot probe's height so a kerb does not read as solid ground at knee level.
static func gap_origin(feet: Vector3, yaw: float, offset: float) -> Vector3:
	return feet + forward(yaw) * offset + Vector3.UP * Tuning.movement.probe_height_foot


## How far down every down-cast looks.
static func gap_depth() -> float:
	return Tuning.movement.gap_probe_depth


## Whether a surface steep enough to climb was hit. Compared against the WORLD
## up axis: a façade has a near-horizontal normal, a ramp does not, and a player
## must never find themselves climbing a staircase.
static func is_climbable(normal: Vector3) -> bool:
	return absf(normal.dot(Vector3.UP)) <= _CLIMBABLE_MAX_UP_DOT
