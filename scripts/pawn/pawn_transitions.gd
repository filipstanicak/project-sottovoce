## THE authority on the pawn's transition graph. TDD-06 §2.2, ADR-0008.
##
## The state-object pattern's real weakness is that the graph exists only in the
## reader's head — fifteen files each knowing one corner of it. This is the fix:
## one place, declared, and asserted edge-for-edge against the normative Mermaid
## diagram in GDD-02 §3 by `test_pawn_transitions.gd`.
##
## **If the code and that diagram disagree, the diagram is right** until an ADR
## says otherwise.
##
## Declared in the same shape the diagram is drawn: GDD-02 groups the six
## locomotion states as `Loco` and draws edges against the group, so `LOCO` here
## expands the same way. That keeps this table readable at a glance instead of
## ninety hand-written rows — and it is NOT parsed from the diagram, so the test
## comparing the two is comparing genuinely independent representations.
class_name PawnTransitions
extends RefCounted

## Every locomotion state can reach these. The diagram draws them as `Loco --> X`.
const LOCO_EXITS: Array[StringName] = [
	PawnStateId.VAULT,
	PawnStateId.CLIMB,
	PawnStateId.DROP,
	PawnStateId.BLENDED,
	PawnStateId.KILL_ANIM,
	PawnStateId.STUN_ANIM,
	PawnStateId.STUNNED,
	PawnStateId.DEAD,
]

## Edges *within* the locomotion group. Escalation UPWARD is strict — there is no
## Idle -> Run, because taking speed one rung at a time is what makes it a
## decision. Coming DOWN is not: every state reaches BlendWalk and Idle directly
## (ADR-0012), because slowing is the escape hatch the whole speed economy
## depends on and a gated escape hatch is not one.
const LOCO_INTERNAL: Dictionary = {
	PawnStateId.IDLE: [PawnStateId.BLEND_WALK, PawnStateId.STROLL],
	PawnStateId.BLEND_WALK: [PawnStateId.IDLE, PawnStateId.STROLL],
	PawnStateId.STROLL: [PawnStateId.BLEND_WALK, PawnStateId.IDLE, PawnStateId.RUN],
	PawnStateId.RUN:
	[PawnStateId.STROLL, PawnStateId.SPRINT, PawnStateId.BLEND_WALK, PawnStateId.IDLE],
	PawnStateId.SPRINT: [PawnStateId.RUN, PawnStateId.BLEND_WALK, PawnStateId.IDLE],
}

## Non-locomotion states. `&"Loco"` is a marker meaning "all six locomotion
## states", exactly as the diagram's `X --> Loco` edges mean.
const LOCO_MARKER := &"Loco"

const NON_LOCO: Dictionary = {
	PawnStateId.RESPAWNING: [PawnStateId.IDLE],
	PawnStateId.VAULT: [LOCO_MARKER, PawnStateId.STUNNED, PawnStateId.DEAD],
	PawnStateId.CLIMB: [LOCO_MARKER, PawnStateId.DROP, PawnStateId.STUNNED, PawnStateId.DEAD],
	PawnStateId.DROP: [LOCO_MARKER],
	PawnStateId.BLENDED:
	[LOCO_MARKER, PawnStateId.KILL_ANIM, PawnStateId.STUNNED, PawnStateId.DEAD],
	PawnStateId.KILL_ANIM: [LOCO_MARKER, PawnStateId.STUNNED, PawnStateId.DEAD],
	PawnStateId.STUN_ANIM: [LOCO_MARKER],
	PawnStateId.STUNNED: [LOCO_MARKER, PawnStateId.DEAD],
	PawnStateId.DEAD: [PawnStateId.RESPAWNING],
}


## from -> Array[StringName] of legal destinations, fully expanded.
static func table() -> Dictionary:
	var out: Dictionary = {}
	for from: StringName in PawnStateId.LOCOMOTION:
		var edges: Array[StringName] = []
		for to: StringName in LOCO_INTERNAL[from]:
			edges.append(to)
		edges.append_array(LOCO_EXITS)
		out[from] = edges
	for from: StringName in NON_LOCO:
		out[from] = _expand(NON_LOCO[from])
	return out


static func _expand(destinations: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for to: Variant in destinations:
		if to == LOCO_MARKER:
			out.append_array(PawnStateId.LOCOMOTION)
		else:
			out.append(to)
	return out


## Whether `from -> to` is legal.
static func allows(from: StringName, to: StringName) -> bool:
	var edges: Variant = table().get(from)
	return edges != null and edges.has(to)


## Every edge as [from, to] pairs, for comparison against the diagram.
static func edges() -> Array:
	var out: Array = []
	var built := table()
	for from: StringName in built:
		for to: StringName in built[from]:
			out.append([from, to])
	return out
