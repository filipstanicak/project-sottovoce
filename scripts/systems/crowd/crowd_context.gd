## **WHAT ONE NPC'S BRAIN CAN SEE.** TDD-08 §3, US-0040. SERVER ONLY.
##
## Passed to `NpcBrain.step()` and to nothing else. PURE — no nodes, no world
## queries; the director fills it and the brain reads it.
##
## **THE OMISSIONS ARE THE DESIGN.** A brain that could see player positions
## could decide to react to a player, and a crowd that reacts to *you*
## specifically is a crowd that tells everyone where you are. GDD-03 §6 gives
## NPCs exactly two things they may respond to — **violence and speed** — and
## both arrive here already reduced to a flag by whoever detected them. There is
## deliberately no `players` array and no `nearest_player`.
##
## `hash` and `corpse` arrive with the spatial hash (US-0042) and corpses
## (US-0044). Declaring them now as nulls of types that do not exist would be two
## fields nobody can use and a compile error each time somebody renames a class
## that has not been written.
class_name CrowdContext
extends RefCounted

## **THE ONE INTERRUPT.** Set by whatever detected violence or a sprinting player
## within the startle radius; cleared by the brain when it consumes it.
##
## A flag rather than a call, because a startle must be **reliable**: players
## read a startle wave as directional information about where something happened,
## and an information channel that sometimes does not fire is worse than none.
## A flag set twice in a tick startles once, which is correct.
var startle_flag: bool = false

## Where to flee from. Only meaningful while `startle_flag` is set.
var startle_origin: Vector3 = Vector3.ZERO

## A gawk token, issued by the director and capped at `TUN-CROWD-GAWK-MAX`.
## **The cap is not a performance measure** — see TDD-08 §3.3: without it a
## corpse in a dense pocket recruits every nearby NPC and drops the pocket below
## `TUN-BLEND-POCKET-MIN-NPC`, which would make the site of a kill *safer* to
## stand in afterwards.
var gawk_granted: bool = false

## The director has given this NPC a formation slot, or taken one away.
var slot_assigned: bool = false
var slot_revoked: bool = false

## The NPC has arrived at an idle anchor — a bench, a stall, a cluster point.
var reached_anchor: bool = false

## The corpse being gawked at has expired, or the gawk was cancelled.
var corpse_gone: bool = false

## **THE SEEDED GENERATOR, AND THE ONLY RANDOMNESS A BRAIN MAY USE.** `randf` and
## `randi` are banned outside `scripts/presentation/` because a match must replay
## identically from its seed — and a crowd that differed between a replay and the
## match it replays would make every recorded playtest unreadable.
var rng: RandomNumberGenerator = null


## Clear every one-shot signal. Called after each brain steps, so an event is
## consumed exactly once — a flag left set would re-fire every tick, and a
## startle that never ended is an NPC that never stops running.
func clear_events() -> void:
	startle_flag = false
	gawk_granted = false
	slot_assigned = false
	slot_revoked = false
	reached_anchor = false
	corpse_gone = false
