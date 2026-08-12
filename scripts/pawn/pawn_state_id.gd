## Every pawn state, by name. GDD-02 §3.1.
##
## FIFTEEN, not fourteen. The normative diagram and the §3.1 state table both
## list fifteen; six places in the prose said "fourteen". GDD-02 §3 says the
## diagram wins, so the prose was corrected rather than the table.
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

## Document order, which is the order GDD-02 §3.1 lists them in.
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
]

## The locomotion sub-machine. GDD-02 §3 draws these inside `state "Locomotion"`,
## and several transitions are declared against the group rather than its members.
const LOCOMOTION: Array[StringName] = [IDLE, BLEND_WALK, STROLL, RUN, SPRINT]


static func is_locomotion(id: StringName) -> bool:
	return LOCOMOTION.has(id)


static func exists(id: StringName) -> bool:
	return ALL.has(id)
