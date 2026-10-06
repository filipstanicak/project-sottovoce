## **WHICH CIVILIANS FORM A GROUP A PLAYER CAN BLEND WITH.** US-0107. SERVER ONLY.
##
## A tag per NPC — `BlendGroupTag` — for `NET-S2C-CROWD-GROUPS`, so every client
## can draw the net under each group and grey a blended player's own.
##
## **FROM NPCs ALONE, OR THE NET WOULD POINT AT PLAYERS.** Every client draws the
## same nets, so a net that appeared, moved or vanished because a player joined
## would be a marker over that player — never-do #12. A walking group's tag is its
## NPC occupants, and the slot a player takes is never an NPC's
## (`WalkingGroup.joinable_slot`). A standing group counts standing NPCs, and a
## player is not an NPC. Nothing here reads a pawn.
##
## **STANDING IS STRICTER THAN THE POCKET, ON PURPOSE.** `SYS-BLEND` grants a
## pocket wherever `TUN-BLEND-POCKET-MIN-NPC` NPCs are within
## `TUN-BLEND-POCKET-RADIUS`, walkers included. The net is drawn only where that
## many *stand*, because a net under a knot of passers-by would promise a blend
## that walks away while the player is still reaching for it. Where the net lies,
## the blend holds; it may also hold in a few places with no net.
class_name CrowdGroups
extends RefCounted

## The current tag of every NPC in the pool, by index.
var tags := PackedByteArray()


## Re-tag the crowd and return what changed since the last call, as flat
## `[npc, tag, npc, tag, ...]`.
func refresh(pool: NpcPool, formations: CrowdFormations, hash: SpatialHash) -> PackedByteArray:
	if pool == null:
		return PackedByteArray()
	var states := PackedInt32Array()
	states.resize(pool.active_count())
	for index: int in states.size():
		var brain := pool.brain_of(index)
		states[index] = brain.state if brain != null else NpcBrain.State.STROLL
	var occupants: Array = []
	if formations != null:
		for group: WalkingGroup in formations.groups:
			occupants.append(group.occupants)
	return apply(tag_all(states, occupants, hash, pool.capacity()))


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
## `NpcBrain.State`, `occupants` each walking group's slot table, and `hash` the
## crowd as `CrowdDirector` indexed it this tick. Returns `capacity` tags.
static func tag_all(
	states: PackedInt32Array, occupants: Array, hash: SpatialHash, capacity: int
) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(maxi(capacity, states.size()))
	out.fill(BlendGroupTag.NONE)
	for group: int in occupants.size():
		for npc: int in occupants[group] as PackedInt32Array:
			if npc >= 0 and npc < states.size():
				out[npc] = BlendGroupTag.formation(group)
	if hash == null:
		return out
	var reach := Tuning.suspicion.blend_pocket_radius
	for index: int in states.size():
		if out[index] != BlendGroupTag.NONE or states[index] != NpcBrain.State.IDLE:
			continue
		var standing := 0
		for other: int in hash.query(hash.position_of(index), reach):
			if other < states.size() and states[other] == NpcBrain.State.IDLE:
				standing += 1
		if standing >= Tuning.suspicion.blend_pocket_min_npc:
			out[index] = BlendGroupTag.STANDING
	return out
