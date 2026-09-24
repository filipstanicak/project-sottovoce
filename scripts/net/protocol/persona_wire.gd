## **A PERSONA AS ONE BYTE.** NETWORK_PROTOCOL, US-0100, ADR-0021. PURE.
##
## `CrowdRoster.PLAYABLE`'s **index** is the wire value, which makes that array's
## order a protocol as well as a derivation input — it already decided every
## roster every seed produces, and now it decides what a client draws. It is
## **append-only**, exactly like `PawnStateId.ALL`, and `test_persona_wire.gd`
## refuses an insertion before an existing member.
##
## **NONE IS 255 AND IT IS A REAL READING.** A player has no persona until the
## countdown deals one, and a client that receives `NONE` must draw *unknown*
## rather than guess — the same rule the Compass bearing follows with
## `NO_CONTRACT`, and for the same reason: a plausible wrong answer is worse than
## an honest absence.
class_name PersonaWire
extends RefCounted

## No persona yet. Not an index, and never confusable with one: the playable set
## would have to reach 256 members before this collided.
const NONE := 255


## Index for a persona name, or `NONE` for anything this build does not know.
## **An unknown name is not an error here** — it is what a renamed or removed
## persona looks like to code that must keep running, and the honest answer is
## the one that draws nothing.
static func to_u8(persona: StringName) -> int:
	var index := CrowdRoster.PLAYABLE.find(persona)
	return NONE if index < 0 else index


## The name for a wire index, or `&""` for `NONE` and for any value this build
## cannot resolve. A client one version behind reads an index it does not have
## and draws unknown, which is why the sentinel and the out-of-range case answer
## the same thing.
static func from_u8(value: int) -> StringName:
	if value < 0 or value >= CrowdRoster.PLAYABLE.size():
		return &""
	return CrowdRoster.PLAYABLE[value]
