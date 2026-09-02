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
	PawnStateId.STAGGERED,
	PawnStateId.LUNGING,
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
	# **`Drop -> Dead` AND `StunAnim -> Dead` WERE MISSING UNTIL 2026-09-02, AND IT
	# WAS NOT COSMETIC.** `KillSystem._land` emitted `killed` and counted the kill
	# whether or not the transition was legal, so a victim killed mid-fall or
	# mid-swing was announced dead, had the cycle repaired around them, had a corpse
	# spawned — and `CombatTargets.is_dead` still answered **false**, because it
	# reads `state_id`. An undead victim is a live target their killer's successor
	# is still hunting. Reported as *"the pawn keeps walking"* since US-0060.
	PawnStateId.DROP: [LOCO_MARKER, PawnStateId.DEAD],
	PawnStateId.BLENDED:
	[LOCO_MARKER, PawnStateId.KILL_ANIM, PawnStateId.STUNNED, PawnStateId.DEAD],
	PawnStateId.KILL_ANIM: [LOCO_MARKER, PawnStateId.STUNNED, PawnStateId.DEAD],
	PawnStateId.STUN_ANIM: [LOCO_MARKER, PawnStateId.DEAD],
	PawnStateId.STUNNED: [LOCO_MARKER, PawnStateId.DEAD],
	PawnStateId.DEAD: [PawnStateId.RESPAWNING],
	# **STUNNABLE AND KILLABLE, AND THE FIRST IS THE ONE WITH AN ARGUMENT.**
	# ADR-0017: a stagger stun could not reach would be a weakening dressed as an
	# addition, which never-do #13 forbids — and GDD-04 §3.4 names *"stun it"* as
	# the counterplay to the ability whose whiff lands here.
	PawnStateId.STAGGERED: [LOCO_MARKER, PawnStateId.STUNNED, PawnStateId.DEAD],
	# **NO `Lunging -> Staggered` AND NO `Lunging -> KillAnim`, WHICH LOOK MISSING
	# AND ARE NOT.** The dash ends into `Idle` at the `pawn` stage; `LungeEffect`
	# reads that at the `abilities` stage and resolves at `combat` — so both the
	# whiff stagger and the auto-kill are entered from **locomotion**, one stage
	# later, through edges that already exist. Adding them here would declare two
	# transitions nothing ever makes.
	PawnStateId.LUNGING: [LOCO_MARKER, PawnStateId.STUNNED, PawnStateId.DEAD],
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
