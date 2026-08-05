## What the traversal probes found this tick. TDD-06 §4, GDD-02 §7.1.
##
## Refreshed once per physics frame, **before** `step()`, and read by the
## resolver (US-0018). Plain data with no engine in it, so every rule that reads
## it is testable by handing it a filled-in instance.
##
## **EVERY FIELD HERE CAME FROM A `WORLD`-ONLY CAST.** That is a determinism
## requirement, not an optimisation: static geometry is identical on every peer,
## while NPC and player positions are interpolated on clients and authoritative
## on the server. A probe that could hit a moving body would resolve differently
## on the two machines, and the client would vault something the server did not.
##
## REUSED, not reallocated. One instance lives on `PawnContext` for the pawn's
## whole life; `clear()` resets it. Sixty allocations a second per pawn is not a
## budget problem yet, and it is not going to become one here.
class_name ProbeResult
extends RefCounted

## This result came from real casts this frame.
##
## **FALSE MEANS "NOTHING IS KNOWN", NOT "NOTHING IS THERE"**, and the two must
## never be confused. `foot_clear and not ground_ahead` is the resolver's edge
## test, and a cleared result satisfies both — so without this flag a pawn whose
## probes had not run yet would resolve to a drop off a cliff that is not there.
var valid: bool = false

## Nothing was hit by any forward probe. Distinguished from "hit at height 0",
## which is a floor.
var has_hit: bool = false

# --- Forward probes (GDD-02 §7.1) ---

## CHEST, 1.35 m. Its hit is what makes a climb possible.
var chest_hit: bool = false

## WAIST, 0.85 m. Its hit is what makes a vault or a mantle possible.
var waist_hit: bool = false

## FOOT, 0.25 m — TRUE WHEN THE PROBE FOUND NOTHING. Inverted deliberately: the
## resolver asks "is the way ahead clear at foot height", and `not foot_hit`
## reads as a double negative at the one place that must not be misread.
var foot_clear: bool = true

## Distance forward to the nearest forward hit, in metres.
var distance: float = 0.0

## Normal of the chest hit, for deciding whether a face is climbable.
var normal: Vector3 = Vector3.UP

## The chest hit is a wall rather than a slope — steep enough to climb.
var surface_is_climbable: bool = false

## Height of the climbable surface's top above the pawn's feet, or `INF` when the
## probes could not see the top. Compared against `TUN-TRAVERSE-CLIMB-MAX-HEIGHT`.
var surface_height: float = INF

# --- Obstacle top (the down-cast beyond a waist hit) ---

## Height above the pawn's feet of the top of the obstacle the waist probe hit,
## or `INF` when there is no top within reach. **THE VAULT/MANTLE DECISION IS
## THIS NUMBER**, so it must never come from an interpolated body.
var obstacle_top: float = INF

## There is somewhere to land on the far side of that obstacle. A vault with
## nothing beyond it is a vault into a wall.
var clear_beyond: bool = false

## Retained from the pre-US-0017 shape. The height of the nearest forward hit,
## which is `obstacle_top` when there is one and the raw hit height otherwise.
var height: float = 0.0

# --- Down probes (gap versus drop) ---

## Ground exists immediately ahead, at roughly the pawn's own level. When this is
## false and `foot_clear` is true, the pawn is at an edge.
var ground_ahead: bool = false

## Horizontal distance to the far side's ground, or `INF` when nothing was found
## within `TUN-TRAVERSE-GAP-MAX`. **`INF` MEANS DROP, a number means gap** — the
## distinction the whole down-probe exists to make.
var gap_distance: float = INF

## Drop from the pawn's feet to whatever is below the edge, or `INF` when the
## probes found nothing within `TUN-TRAVERSE-GAP-PROBE-DEPTH`.
var drop_height: float = INF

## Yaw offset, radians, at which the far side was found. Zero when the pawn is
## already facing across the gap.
##
## GDD-02 §7.3's auto-align: a player should not have to be square to a gap they
## can plainly see. Bounded by `TUN-TRAVERSE-GAP-ALIGN-ARC`, so it forgives aim
## and never turns you toward a gap you were not crossing.
var gap_yaw_offset: float = 0.0

# --- Ledge (airborne only) ---

## A grabbable ledge is in reach. **THE FORGIVENESS CASE**, and §7.2 case 1:
## catching a ledge you are falling past beats everything else.
var ledge_found: bool = false

## Signed lateral offset to that ledge, metres — negative is to the pawn's left.
## Bounded by `TUN-TRAVERSE-MAGNET-RADIUS`; this is what "not being laterally
## aligned with the ledge" is forgiven by.
var ledge_lateral: float = 0.0

## Height of the ledge above the pawn's feet.
var ledge_height: float = INF


## True when the pawn is standing at an edge: nothing at foot height ahead, and
## no ground ahead either.
##
## Requires `valid`, because an unprobed result satisfies both halves. Cases 2
## and 3 of GDD-02 §7.2 — gap jump and drop — both begin here, and both throw the
## pawn off whatever they are standing on.
func at_edge() -> bool:
	return valid and foot_clear and not ground_ahead


## True when a landing was found within the jumpable range.
func gap_is_crossable(max_gap: float) -> bool:
	return gap_distance <= max_gap


## True when a grabbable ledge sits within `radius` metres laterally.
##
## Requires `valid` for the same reason `at_edge()` does: an unprobed result has
## `ledge_found` false, but a caller reading the fields directly could not tell
## "no ledge" from "never looked", and this is the branch that decides whether a
## falling player catches themselves.
func ledge_within(radius: float) -> bool:
	return valid and ledge_found and absf(ledge_lateral) <= radius


## Reset to "found nothing". Called at the top of every refresh, so a stale
## reading can never survive into a frame whose casts all missed.
func clear() -> void:
	valid = false
	has_hit = false
	chest_hit = false
	waist_hit = false
	foot_clear = true
	distance = 0.0
	normal = Vector3.UP
	surface_is_climbable = false
	surface_height = INF
	obstacle_top = INF
	clear_beyond = false
	height = 0.0
	ground_ahead = false
	gap_distance = INF
	drop_height = INF
	gap_yaw_offset = 0.0
	ledge_found = false
	ledge_lateral = 0.0
	ledge_height = INF
