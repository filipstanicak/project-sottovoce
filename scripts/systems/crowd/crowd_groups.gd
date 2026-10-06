## **WHICH CIVILIANS FORM A GROUP A PLAYER CAN BLEND WITH.** US-0107. SERVER ONLY.
##
## A tag per NPC — `BlendGroupTag` — for `NET-S2C-CROWD-GROUPS`, so every client
## can draw the net under each group and grey a blended player's own.
##
## **FROM NPCs ALONE, OR THE NET WOULD POINT AT PLAYERS.** Every client draws the
## same nets, so a net that appeared, moved or vanished because a player joined
## would be a marker over that player — never-do #12. A walking group's tag is its
## NPC occupants, and the slot a player takes is never an NPC's
## (`WalkingGroup.joinable_slot`). A standing civilian is an idle NPC, and a
## player is not an NPC. A seat's tag is the NPC `LeanSpots` says holds it, and a
## player can neither take a held seat nor turn an NPC's hold into anything else.
## Nothing here reads a pawn.
##
## **STANDING IS STRICTER THAN THE POCKET, ON PURPOSE.** `SYS-BLEND` grants a
## pocket wherever `TUN-BLEND-POCKET-MIN-NPC` NPCs are within
## `TUN-BLEND-POCKET-RADIUS`, walkers included. The net is drawn only where that
## many *stand*, because a net under a knot of passers-by would promise a blend
## that walks away while the player is still reaching for it. Where the net lies,
## the blend holds; it may also hold in a few places with no net. The client draws
## it from these tags (`BlendCueRules.group_nets`).
class_name CrowdGroups
extends RefCounted

## The current tag of every NPC in the pool, by index.
var tags := PackedByteArray()


## Re-tag the crowd and return what changed since the last call, as flat
## `[npc, tag, npc, tag, ...]`.
func refresh(pool: NpcPool, formations: CrowdFormations, spots: LeanSpots) -> PackedByteArray:
	if pool == null:
		return PackedByteArray()
	var states := PackedInt32Array()
	var holds := PackedInt32Array()
	states.resize(pool.active_count())
	holds.resize(pool.active_count())
	for index: int in states.size():
		var brain := pool.brain_of(index)
		states[index] = brain.state if brain != null else NpcBrain.State.STROLL
		holds[index] = spots.spot_held_by(index) if spots != null else LeanSpots.VACANT
	var occupants: Array = []
	if formations != null:
		for group: WalkingGroup in formations.groups:
			occupants.append(group.occupants)
	return apply(tag_all(states, occupants, holds, pool.capacity()))


## Take `fresh` as the current tags and return the pairs that differ from before.
func apply(fresh: PackedByteArray) -> PackedByteArray:
	var changed := PackedByteArray()
	for index: int in fresh.size():
		var before := tags[index] if index < tags.size() else BlendGroupTag.NONE
		if fresh[index] != before:
			changed.append(index)
			changed.append(fresh[index])
	tags = fresh
	return changed


## Every tag that is not `NONE`, as pairs: what a player arriving mid-match needs.
func full_table() -> PackedByteArray:
	var pairs := PackedByteArray()
	for index: int in tags.size():
		if tags[index] != BlendGroupTag.NONE:
			pairs.append(index)
			pairs.append(tags[index])
	return pairs


## **THE RULE, OVER PLAIN DATA.** `states` holds each active NPC's
## `NpcBrain.State`, `occupants` each walking group's slot table, and `holds` the
## static prop each NPC holds or `LeanSpots.VACANT`. Returns `capacity` tags.
##
## **WHAT EACH CIVILIAN IS, AND NOTHING ABOUT WHERE A POCKET IS.** The second version
## tagged the knots a pocket could be taken in, and a member at the edge of one was
## drawn a net of its own where the server refused the pocket (review of #252). The
## client now works out from standing positions where the pocket rule is guaranteed,
## so this only has to say who is standing.
static func tag_all(
	states: PackedInt32Array, occupants: Array, holds: PackedInt32Array, capacity: int
) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(maxi(capacity, states.size()))
	out.fill(BlendGroupTag.NONE)
	for group: int in occupants.size():
		for npc: int in occupants[group] as PackedInt32Array:
			if npc >= 0 and npc < states.size():
				out[npc] = BlendGroupTag.formation(group)
	for index: int in states.size():
		if out[index] != BlendGroupTag.NONE:
			continue
		if index < holds.size() and holds[index] != LeanSpots.VACANT:
			out[index] = BlendGroupTag.prop(holds[index])
		elif states[index] == NpcBrain.State.IDLE:
			out[index] = BlendGroupTag.STANDING
	return out
