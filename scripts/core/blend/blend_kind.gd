## **THE FOUR BLEND ACTIONS, AS THE WIRE'S `u4`.** GDD-03 §4.1,
## NETWORK_PROTOCOL §4, `EVT-BLEND-STATE-CHANGED`, US-0053. PURE.
##
## `SIGNAL_AND_EVENT_BUS` names these five values and the snapshot spends four
## bits on them, so **the ordinals are the protocol**: appending is safe,
## reordering silently tells a client on a different build that a player hiding in
## a well is standing in a crowd.
##
## **`NONE` IS ZERO SO THAT AN UNFILLED FIELD DECODES AS "NOT BLENDED"** rather
## than as the first real kind — the same reason `SlotTable` reserves slot 0 for
## nobody. A record nobody wrote must never read as a claim.
class_name BlendKind
extends RefCounted

enum Kind { NONE, POCKET, GROUP, PROP_STATIC, PROP_CONCEAL }


## Does this blend depend on where the crowd is standing *this tick*?
##
## **THE DIVIDING LINE OF THE WHOLE SYSTEM.** A crowd-dependent blend can be taken
## away by people who are not the hunter — a Startle scatters a pocket, a group
## walks its circuit — and that is what makes it findable and therefore fair. The
## prop blends cannot, which is why GDD-03 §4.1.3 has to reach for a *positional*
## counterplay instead: a bench in an empty street is conspicuous while being
## mechanically anonymous.
static func is_crowd_dependent(kind: int) -> bool:
	return kind == Kind.POCKET or kind == Kind.GROUP


## True for anything but `NONE`. A named question rather than `!= NONE` scattered
## everywhere, because the comparison is against the *zero* and that is exactly
## the comparison that gets written as a truthiness test by accident.
static func is_blend(kind: int) -> bool:
	return kind != Kind.NONE


## Fits `NETWORK_PROTOCOL` §4's `blend_state:u4`. Asserted rather than assumed:
## the field is four bits and the enum is free to grow past sixteen without
## anything complaining until a client decodes a neighbour's kind.
static func fits_the_wire() -> bool:
	return Kind.size() <= 16
