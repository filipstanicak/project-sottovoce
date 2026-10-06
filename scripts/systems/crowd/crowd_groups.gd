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
## player is not an NPC. A seat's tag is the NPC `LeanSpots` says holds it, and a
## player can neither take a held seat nor turn an NPC's hold into anything else.
## Nothing here reads a pawn.
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
func refresh(
	pool: NpcPool, formations: CrowdFormations, spots: LeanSpots, hash: SpatialHash
) -> PackedByteArray:
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
	return apply(tag_all(states, occupants, holds, hash, pool.capacity()))


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
## `NpcBrain.State`, `occupants` each walking group's slot table, `holds` the static
## prop each NPC holds or `LeanSpots.VACANT`, and `hash` the crowd as
## `CrowdDirector` indexed it this tick. Returns `capacity` tags.
##
## **A KNOT IS EVERY STANDING CIVILIAN NEAR A CENTRE, NOT ONLY THE CENTRES** (review
## of #252). A centre is a standing civilian with `TUN-BLEND-POCKET-MIN-NPC` standing
## civilians — itself included — within `TUN-BLEND-POCKET-RADIUS`. Tagging only the
## centres left a pocket the server granted, four civilians 3.4 m round the player,
## with one of its four marked.
static func tag_all(
	states: PackedInt32Array,
	occupants: Array,
	holds: PackedInt32Array,
	hash: SpatialHash,
	capacity: int
) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(maxi(capacity, states.size()))
	out.fill(BlendGroupTag.NONE)
	for group: int in occupants.size():
		for npc: int in occupants[group] as PackedInt32Array:
			if npc >= 0 and npc < states.size():
				out[npc] = BlendGroupTag.formation(group)
	for index: int in mini(states.size(), holds.size()):
		if out[index] == BlendGroupTag.NONE and holds[index] != LeanSpots.VACANT:
			out[index] = BlendGroupTag.prop(holds[index])
	if hash == null:
		return out
	var centres := _centres(states, hash)
	var reach := Tuning.suspicion.blend_pocket_radius
	for index: int in states.size():
		if out[index] != BlendGroupTag.NONE or states[index] != NpcBrain.State.IDLE:
			continue
		out[index] = BlendGroupTag.STILL
		for other: int in hash.query(hash.position_of(index), reach):
			if other < centres.size() and centres[other] == 1:
				out[index] = BlendGroupTag.STANDING
				break
	return out


## 1 for every standing civilian that has enough standing civilians round it.
static func _centres(states: PackedInt32Array, hash: SpatialHash) -> PackedByteArray:
	var centres := PackedByteArray()
	centres.resize(states.size())
	var reach := Tuning.suspicion.blend_pocket_radius
	for index: int in states.size():
		if states[index] != NpcBrain.State.IDLE:
			continue
		var standing := 0
		for other: int in hash.query(hash.position_of(index), reach):
			if other < states.size() and states[other] == NpcBrain.State.IDLE:
				standing += 1
		centres[index] = 1 if standing >= Tuning.suspicion.blend_pocket_min_npc else 0
	return centres
