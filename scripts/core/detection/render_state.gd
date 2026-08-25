## **THE ANONYMITY RULE.** GDD-03 §2.1, TDD-07 §4.1, US-0055. PURE.
##
## For every ordered pair (observer **O**, subject **S**), what O sees of S. Two
## bits on the wire, per observer, per tick — and the whole of what one player
## ever learns about another's suspicion.
##
## **SUSPICION IS NOT A BROADCAST, AND THIS FUNCTION IS WHY.** A player at 95
## looks completely ordinary to everyone except their hunter and, if Exposed,
## their prey. At six players that is **four of five observers seeing nothing**,
## which is what stops the match collapsing into everyone converging on whoever
## is currently visible.
##
## **THE RELATIONSHIP DECIDES THE CHANNEL, NOT THE VALUE.** The same player at the
## same suspicion is rendered differently to different observers *simultaneously*.
## That is why this is a per-observer snapshot field and not a material swap on a
## shared mesh — a material swap can only say one thing at a time.
##
## **AND EXPOSED CUTS BOTH WAYS.** Visible to your hunter, who can now kill you
## more easily, *and* to your prey, who is warned. One mechanic, two punishments.
class_name RenderState
extends RefCounted

## Two bits. **`PLAIN` IS ZERO** so a record nobody filled in decodes as "nothing
## to see" rather than as a tint somebody has to explain — the same reason
## `SlotTable` reserves slot 0 and `BlendKind.NONE` is zero.
enum State { PLAIN, TINTED, HARD }


## What `observer` sees of `subject`.
##
## `hunts` is "the observer holds the subject as their contract"; `hunted_by` is
## the reverse. **Both are the ANNOUNCED contract, never the graph's** — during
## `TUN-CONTRACT-REASSIGN-DELAY` the graph is ahead of what players have been
## told, and rendering from it would tint a player the hunter has not been given
## yet. The Compass would say nothing while the silhouette said everything.
static func of(subject_tier: int, hunts: bool, hunted_by: bool) -> int:
	if subject_tier == SuspicionMath.Tier.ANONYMOUS:
		return State.PLAIN
	if hunts:
		return State.HARD if subject_tier == SuspicionMath.Tier.EXPOSED else State.TINTED
	# **YOUR PURSUER, IF RECKLESS.** Nothing at Noticed: the prey's channel is the
	# Compass warning, and giving them a tint as well would let them track a
	# Noticed hunter continuously — which is TDD-07 §9 question 1, answered *no*.
	if hunted_by and subject_tier == SuspicionMath.Tier.EXPOSED:
		return State.HARD
	return State.PLAIN


## Does this state draw through geometry?
##
## **THE EXPOSED OUTLINE IS THE ONLY X-RAY IN THE GAME** (GDD-03 §2.3), and it is
## the punishment. A named question rather than `== HARD` scattered through the
## presentation layer, so the prohibition has one place to be broken and one place
## to be guarded.
static func draws_through_geometry(state: int) -> bool:
	return state == State.HARD


## Fits `NETWORK_PROTOCOL` §4's `render_state:u2`, asserted rather than assumed —
## the field is two bits and the enum is free to grow past four without anything
## complaining until a client decodes a neighbour's state as somebody else's.
static func fits_the_wire() -> bool:
	return State.size() <= 4
