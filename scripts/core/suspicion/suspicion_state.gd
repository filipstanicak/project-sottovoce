## **EVERYTHING THE SUSPICION INTEGRATOR IS ALLOWED TO KNOW.** GDD-03 §3.3,
## TDD-07 §2.1, US-0051. PURE.
##
## A plain record, deliberately. `SuspicionMath.integrate()` is a function of this,
## the tuning and `dt` and of **nothing else** — no pawn, no world, no clock — which
## is what lets the highest-risk arithmetic in the project be exercised in
## microseconds with no engine.
##
## **THE OMISSIONS ARE THE DESIGN.** There is no field for who is watching, no field
## for the tier, and no field for score. Detection reads the tier that comes *out*
## of here (`SystemOrder` puts suspicion before detection for exactly that reason),
## and a value that fed back in would be a loop nobody could reason about.
class_name SuspicionState
extends RefCounted

## The scalar, `[TUN-SUSPICION-MIN, TUN-SUSPICION-MAX]`.
var value: float = 0.0

## Ground speed in m/s. **Separate from `speed_state`** because the decay cliff is
## a *speed* (`TUN-SUSPICION-DECAY-SPEED-CEILING`) while the gains are *states*: a
## pawn decelerating out of a run is below the cliff before it leaves the state, and
## a pawn shoved by the crowd is above it while standing in Stroll.
var speed: float = 0.0

## A `PawnStateId` constant. `&""` for a state that costs nothing.
var speed_state: StringName = &""

## True while the pawn is at or above `TUN-SUSPICION-ROOF-HEIGHT`. **Presence, not
## movement** — standing still on a roof costs 18/s, because no civilian is up
## there and that is the whole reason the roofs are a shortcut worth pricing.
var on_roof: bool = false

## Metres to the nearest NPC, or `INF` when the crowd has not been asked yet.
## Compared against `TUN-SUSPICION-OPEN-RADIUS`.
var nearest_npc_distance: float = INF

## Net ticks since the last tick that produced any gain. Decay is armed only once
## this reaches `TUN-SUSPICION-DECAY-DELAY` — the rule that closes the tap-sprint
## exploit. **The owner advances it from `SuspicionMath.gained()`**, never from its
## own reading of the state, or the two can disagree about what a gain was.
var ticks_since_gain: int = 0

## True while a blend action is held. Overrides gain and decay both.
var blending: bool = false

## `PASV-STILLNESS` equipped. Multiplies decay while genuinely stationary.
var has_stillness: bool = false


## A copy, so a caller can keep last tick's reading without the next tick editing it
## underneath them.
func duplicate_state() -> SuspicionState:
	var out := SuspicionState.new()
	out.value = value
	out.speed = speed
	out.speed_state = speed_state
	out.on_roof = on_roof
	out.nearest_npc_distance = nearest_npc_distance
	out.ticks_since_gain = ticks_since_gain
	out.blending = blending
	out.has_stillness = has_stillness
	return out
