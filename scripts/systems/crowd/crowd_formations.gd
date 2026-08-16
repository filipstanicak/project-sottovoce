## **THE FOUR WALKING GROUPS, THEIR SLOTS, AND WHO IS IN THEM.** GDD-03 §4.1.2,
## GDD-05 §5.2, TDD-08 §8, US-0043. SERVER ONLY.
##
## Split out of `CrowdDirector`, which TDD-08 §8 puts this on, for the reason
## never-do #6 exists: the director already owns the tick, the brains and the
## steering, and one file holding all of that plus formations would be past 400
## lines before US-0044 adds a corpse to it. It was called `GroupManager` for
## about an hour, until `test_no_utils_files.gd` refused the suffix — correctly:
## "manager" names an authority rather than a responsibility, and the
## responsibility is the four formations.
##
## **A GROUP RECRUITS BY WALKING PAST PEOPLE.** The formation never asks an NPC to
## catch up, and that is not an optimisation — a civilian who broke into a jog to
## join a procession would be moving faster than `TUN-CROWD-NPC-SPEED-STROLL`,
## which is the one speed invariant 1 pins to `TUN-SPEED-BLENDWALK`. So an empty
## slot is filled only from whoever is *already* inside
## `TUN-BLEND-GROUP-JOIN-RADIUS` of it when the director looks. Groups therefore
## fill as they sweep the district, which is also what a procession looks like.
##
## **THE SAME RADIUS A PLAYER JOINS AT**, deliberately: GDD-03 §6.2 says every NPC
## shares the machine and differs only in parameters, and a crowd that could form
## up on terms no player can meet would be a crowd whose behaviour a player cannot
## learn from.
class_name CrowdFormations
extends RefCounted

## Nobody holds the joinable slot. `SlotTable`'s convention, for the same reason.
const NO_PEER := 0

var groups: Array[WalkingGroup] = []


## One group per circuit in the map. **Nothing is invented here**: if the map
## declares no circuits, there are no groups and `WALKING_GROUP` stays a state
## nothing can enter, which is exactly what it was before this story.
func setup(map: MapData) -> void:
	groups.clear()
	if map == null:
		return
	for route: PackedVector3Array in map.circuits:
		var circuit := CrowdCircuit.new()
		circuit.setup(route)
		var group := WalkingGroup.new()
		group.setup(circuit, int(Tuning.crowd.group_size), Tuning.crowd.group_spacing)
		groups.append(group)


## **THE DISTRICT STARTS WITH ITS PROCESSIONS ALREADY WALKING.** Called once, at
## match start, after `CrowdPlacement` has put the crowd down.
##
## Recruitment alone cannot do this. A group sweeps a 2.5 m tube along a 150 m
## route in 107 s, which on a 120 x 120 m district with 78 civilians picks up
## roughly four people **per lap** — so the four walking groups would not exist
## for the first minute or two of an eight-minute match. The walking group is one
## of only four blends and the only one that lets a player travel; a blend that is
## missing for a fifth of the match is a blend nobody plans around.
##
## The NPCs are moved to their slots, which is a teleport, and it happens on the
## frame the match is built — before any client has been welcomed, let alone
## rendered anything.
##
## **A GROUP IS ONLY FORMED IF THE CROWD CAN SPARE IT.** Processions must never
## outnumber the standing crowd: `TUN-BLEND-POCKET-MIN-NPC` needs four NPCs within
## `TUN-BLEND-POCKET-RADIUS` for the *other* blend to exist at all, and a district
## that had traded every pocket for a corridor would have one hiding strategy
## instead of four. On the shipped 78-NPC crowd all four groups form, which is 16
## of 78 exactly as GDD-05 §5.2 intends.
func form(pool: NpcPool) -> void:
	var active := pool.active_count()
	var taken := 0
	var slot_size: int = int(Tuning.crowd.group_size)
	for group: WalkingGroup in groups:
		if (taken + slot_size) * 2 > active:
			return
		for slot: int in slot_size:
			var npc := _nearest_unslotted(group.slot_position(slot), pool)
			if npc == WalkingGroup.EMPTY:
				return
			group.occupy(slot, npc)
			pool.set_position(npc, group.slot_position(slot))
			pool.context_of(npc).slot_assigned = true
			taken += 1
	Log.info(
		(
			"processions formed: %d NPCs across %d of %d circuits"
			% [taken, taken / maxi(slot_size, 1), groups.size()]
		),
		&"crowd"
	)


## The active NPC closest to `point` that no group already holds. Brute force
## over the crowd, once, at match start — the spatial hash is not built until the
## first tick, and a hundred distance checks at setup is not a hot path.
func _nearest_unslotted(point: Vector3, pool: NpcPool) -> int:
	var best := WalkingGroup.EMPTY
	var best_distance := INF
	for npc: int in pool.active_count():
		if _group_holding(npc) != -1:
			continue
		var body := pool.body_of(npc)
		if body == null:
			continue
		var away := body.global_position.distance_to(point)
		if away < best_distance:
			best_distance = away
			best = npc
	return best


## Move every formation along its route and steer whoever is in it.
##
## **THE GROUP WALKS AT THE CROWD'S SPEED, NOT AT ITS DECLARED PERIOD.** See
## `CrowdCircuit.period_at` and US-0043: `MapData.circuit_periods` says 55–75 s
## and the routes are 150–237 m long, which is 2.6–3.2 m/s. A walking group is the
## one blend that lets a player *travel* while gaining anonymity; at twice
## blend-walk it would be a speed cheat wearing a crowd.
func advance(pool: NpcPool, steering: Steering, dt: float) -> void:
	var speed: float = Tuning.crowd.npc_speed_stroll
	for group: WalkingGroup in groups:
		group.advance(speed * dt * _pace(group, pool))
		for slot: int in group.slot_count():
			var npc: int = group.occupants[slot]
			if npc == WalkingGroup.EMPTY:
				continue
			var body := pool.body_of(npc)
			var agent := pool.agent_of(npc)
			if body != null and agent != null:
				steering.drive_to(body, agent, group.slot_position(slot), speed)


## **THE PROCESSION WAITS FOR ITS STRAGGLERS**, between 1.0 (nobody is behind) and
## 0.0 (somebody is a full slot-spacing behind and the group holds).
##
## Without this the formation is unrecoverable. A slot moves at exactly
## `TUN-CROWD-NPC-SPEED-STROLL` and so does the NPC chasing it, so any lag — one
## RVO sidestep round a passing civilian, one corner taken wide — is never closed:
## the gap only grows until `_revoke_the_departed` drops that member, and a group
## sheds people it can never take back.
##
## The alternative is letting a straggler walk faster to catch up, and that is the
## one thing it must not do: invariant 1 pins the crowd's speed to
## `TUN-SPEED-BLENDWALK` precisely so a blending player is indistinguishable from
## it, and a clone breaking into a jog is a clone a player cannot imitate.
func _pace(group: WalkingGroup, pool: NpcPool) -> float:
	var worst := 0.0
	for slot: int in group.slot_count() - 1:
		var npc: int = group.occupants[slot]
		if npc == WalkingGroup.EMPTY:
			continue
		var body := pool.body_of(npc)
		if body == null:
			continue
		var away := body.global_position - group.slot_position(slot)
		away.y = 0.0
		worst = maxf(worst, away.length())
	return clampf(1.0 - worst / Tuning.crowd.group_spacing, 0.0, 1.0)


## The director's 2 s work: fill empty slots, and let go of anybody who has
## stopped being in the group.
##
## **REVOCATION FIRST.** A slot held by an NPC that startled away is a slot no
## recruitment pass can fill, and the group would walk the rest of the match with
## a hole in it — visible as a formation that never closes up.
func rebalance(hash: SpatialHash, pool: NpcPool) -> void:
	for group: WalkingGroup in groups:
		_revoke_the_departed(group, pool)
		_recruit(group, hash, pool)


## Anyone whose brain has left `WALKING_GROUP`, or who has drifted further from
## their slot than the formation is wide.
##
## The drift limit is `TUN-CROWD-GROUP-SPACING` because that is the distance at
## which an NPC is closer to somebody else's slot than to its own — not
## `TUN-BLEND-GROUP-SLOT-TOLERANCE`, which is the *player's* break condition and
## is tighter than RVO can hold a body against a crowd.
func _revoke_the_departed(group: WalkingGroup, pool: NpcPool) -> void:
	for slot: int in group.slot_count() - 1:
		var npc: int = group.occupants[slot]
		if npc == WalkingGroup.EMPTY:
			continue
		var brain := pool.brain_of(npc)
		var body := pool.body_of(npc)
		var lost := brain == null or brain.state != NpcBrain.State.WALKING_GROUP
		if not lost and body != null:
			var away := body.global_position - group.slot_position(slot)
			away.y = 0.0
			lost = away.length() > Tuning.crowd.group_spacing
		if lost:
			group.release(slot)
			if brain != null and brain.state == NpcBrain.State.WALKING_GROUP:
				pool.context_of(npc).slot_revoked = true


## Fill what is empty from whoever the formation is currently passing.
func _recruit(group: WalkingGroup, hash: SpatialHash, pool: NpcPool) -> void:
	var slot := group.free_npc_slot()
	while slot != WalkingGroup.EMPTY:
		var npc := _candidate_near(group.slot_position(slot), hash, pool)
		if npc == WalkingGroup.EMPTY:
			return
		group.occupy(slot, npc)
		pool.context_of(npc).slot_assigned = true
		slot = group.free_npc_slot()


## The nearest unslotted NPC within `TUN-BLEND-GROUP-JOIN-RADIUS` of `point`, or
## `EMPTY`. **The spatial hash's first gameplay consumer.**
func _candidate_near(point: Vector3, hash: SpatialHash, pool: NpcPool) -> int:
	var best := WalkingGroup.EMPTY
	var best_distance := INF
	for npc: int in hash.query(point, Tuning.suspicion.blend_group_join_radius):
		if not pool.is_active(npc) or _group_holding(npc) != -1:
			continue
		var brain := pool.brain_of(npc)
		if brain == null or not _recruitable(brain.state):
			continue
		var body := pool.body_of(npc)
		if body == null:
			continue
		var away := body.global_position.distance_to(point)
		if away < best_distance:
			best_distance = away
			best = npc
	return best


## Stroll and Idle only. A startled NPC is fleeing and a gawking one is busy;
## both refusals are in `NpcBrain.TRANSITIONS` already, so recruiting them would
## produce an assignment the machine silently ignores — a slot marked full and an
## NPC that never walks to it.
func _recruitable(state: int) -> bool:
	return state == NpcBrain.State.STROLL or state == NpcBrain.State.IDLE


func _group_holding(npc: int) -> int:
	for index: int in groups.size():
		if groups[index].slot_of(npc) != WalkingGroup.EMPTY:
			return index
	return -1


## Where slot-holder `npc` should aim its **navigation target**, `metres` further
## along the circuit than its slot, or `Vector3.INF` if it holds no slot.
##
## **A `NavigationAgent3D` THAT HAS ARRIVED STOPS AVOIDING.** Measured, and it
## cost an afternoon: an agent whose `target_position` it has reached — or never
## had — answers `velocity_computed` with **exactly zero**, whatever
## `set_velocity()` was handed. Formation members were driven at 1.4 m/s and stood
## perfectly still while the slot walked away from them, and nothing anywhere
## errored.
##
## So slot seeking still needs a target; it just must not be the slot. Aiming one
## rebalance-interval's travel *ahead* means the agent is never finished, re-aims
## about once every `TUN-CROWD-DIRECTOR-INTERVAL`, and costs the repath budget
## roughly a third of a query per tick instead of sixteen.
func lookahead_for(npc: int, metres: float) -> Vector3:
	for group: WalkingGroup in groups:
		var slot := group.slot_of(npc)
		if slot == WalkingGroup.EMPTY:
			continue
		var ahead := WalkingGroup.new()
		ahead.setup(group.circuit, group.slot_count() - 1, Tuning.crowd.group_spacing)
		ahead.distance = group.distance + metres
		return ahead.slot_position(slot)
	return Vector3.INF


## The nearest group whose joinable slot is free and within `radius` of `point`,
## or -1. What `SYS-BLEND` will call when a player presses `INPUT-BLEND`.
func joinable_group(point: Vector3, radius: float) -> int:
	var best := -1
	var best_distance := radius
	for index: int in groups.size():
		var group := groups[index]
		if group.player_peer != NO_PEER:
			continue
		var away := group.slot_position(group.joinable_slot()).distance_to(point)
		if away <= best_distance:
			best_distance = away
			best = index
	return best


## Give the joinable slot to `peer`. Refuses a taken slot rather than evicting,
## because a blend that could be stolen is a blend nobody can rely on.
func claim(peer: int, index: int) -> bool:
	if index < 0 or index >= groups.size() or peer == NO_PEER:
		return false
	if groups[index].player_peer != NO_PEER:
		return false
	release(peer)
	groups[index].player_peer = peer
	return true


## Let go of whatever `peer` holds. **Called on disconnect as well as on leaving
## the blend** — ENet reuses peer ids, so a slot left held is a slot the next
## joiner inherits, and they would be blending without having asked.
func release(peer: int) -> void:
	for group: WalkingGroup in groups:
		if group.player_peer == peer:
			group.player_peer = NO_PEER


func group_of_peer(peer: int) -> int:
	for index: int in groups.size():
		if groups[index].player_peer == peer:
			return index
	return -1


## Where `peer` must stand to keep the blend, or `Vector3.INF` if they hold no
## slot. `INF` rather than the origin, for the reason `RewoundWorld` uses it: the
## origin is a real place on this map.
func slot_position_of(peer: int) -> Vector3:
	var index := group_of_peer(peer)
	if index < 0:
		return Vector3.INF
	var group := groups[index]
	return group.slot_position(group.joinable_slot())
