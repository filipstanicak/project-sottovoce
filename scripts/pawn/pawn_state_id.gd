## Every pawn state, by name. GDD-02 §3.1.
##
## FIFTEEN, and the number has been right, wrong, right, wrong and right again.
## Fifteen were declared at M0; six places in the prose said fourteen and were
## corrected against the normative table; the `Jog` rung was deprecated on
## 2026-08-12 and took it to fourteen for real; **ADR-0017 added `Staggered` on
## 2026-09-01** and it is fifteen once more. `test_pawn_state_count.gd` exists
## because a prose number is not checkable and this one has never stayed still.
##
## StringName because these are compared every tick, on every pawn, on the server.
class_name PawnStateId
extends RefCounted

const RESPAWNING := &"Respawning"
const IDLE := &"Idle"
const BLEND_WALK := &"BlendWalk"
const STROLL := &"Stroll"

## **DEPRECATED 2026-08-12.** The ladder lost its Jog rung: `INPUT-RUN` means Run
## now, and nothing transitions here. Retained and never reused, per
## NAMING_AND_IDS §2.3 — a retired ID that vanishes is one a future reader can
## rediscover and give a second meaning to. It is deliberately absent from `ALL`
## and `LOCOMOTION`, so no machine can register or reach it.
const JOG := &"Jog"

const RUN := &"Run"
const SPRINT := &"Sprint"
const CLIMB := &"Climb"
const VAULT := &"Vault"
const DROP := &"Drop"
const BLENDED := &"Blended"
const KILL_ANIM := &"KillAnim"
const STUN_ANIM := &"StunAnim"
const STUNNED := &"Stunned"
const DEAD := &"Dead"

## **ADR-0017.** A committed action failed — a lost kill contest, a refused stun,
## or a whiffed Lunge. **`Stunned` is done to you by another player; `Staggered`
## is done to you by your own failed action**, and that one line is the whole
## distinction between two states whose names sit one letter apart.
const STAGGERED := &"Staggered"

## **THIS ORDER IS THE WIRE, AND IT IS APPEND-ONLY.** `Snapshot.state_index`
## encodes `state_id` as an index into this array, so inserting a name in the
## middle silently remaps every remote pawn's animation to a different state —
## a defect that would look like a rendering fault and read as plausible at every
## position. Appending is safe and is the only safe edit.
##
## It also happens to be GDD-02 §3.1's table order, which is a **coincidence
## worth not relying on**: the table is free to be reordered for readability and
## this array is not. `test_pawn_state_count.gd` compares the two as sets.
const ALL: Array[StringName] = [
	RESPAWNING,
	IDLE,
	BLEND_WALK,
	STROLL,
	RUN,
	SPRINT,
	CLIMB,
	VAULT,
	DROP,
	BLENDED,
	KILL_ANIM,
	STUN_ANIM,
	STUNNED,
	DEAD,
	STAGGERED,
]

## The locomotion sub-machine. GDD-02 §3 draws these inside `state "Locomotion"`,
## and several transitions are declared against the group rather than its members.
const LOCOMOTION: Array[StringName] = [IDLE, BLEND_WALK, STROLL, RUN, SPRINT]


static func is_locomotion(id: StringName) -> bool:
	return LOCOMOTION.has(id)


static func exists(id: StringName) -> bool:
	return ALL.has(id)
