## **WHO STANDS AT WHICH STALL COUNTER.** GDD-03 §4.1.3 and §6.3 rule 7, US-0103. PURE.
##
## *"Clones must be able to occupy every blend action a player can"* — and until this
## existed no NPC ever leaned at a counter, so a player leaning at one was the only
## figure ever seen there. The twelve lean spots (`MapData.static_props`, two per
## market stall) are now held by players **and** NPCs through this one record.
##
## **ONE FIGURE PER SPOT, WHOEVER IT IS.** A spot is where one person stands to lean
## on a 0.9 m counter. A player who finds it taken is refused with
## `BlendRefusal.Why.PROP_OCCUPIED`, as at a concealment prop — and because the holder
## is standing there in plain view, the refusal tells them nothing the street did not.
## An NPC never takes a spot somebody holds, and never leaves one *because* a player
## wants it: a civilian that stepped aside for whoever walked up would mark them.
##
## **KEYED BY HOLDER IN BOTH DIRECTIONS**, `PropOccupancy`'s rule: a spot left held by a
## peer that disconnected, or by an NPC that was startled away, would vanish from the
## market for the rest of the match.
class_name LeanSpots
extends RefCounted

const VACANT := -1

## spot -> peer id, and spot -> NPC index. A spot is in at most one of the two.
var _players: Dictionary = {}
var _npcs: Dictionary = {}
## The reverse: peer -> spot, and NPC index -> spot.
var _by_peer: Dictionary = {}
var _by_npc: Dictionary = {}


func is_vacant(spot: int) -> bool:
	return not _players.has(spot) and not _npcs.has(spot)


func player_at(spot: int) -> int:
	return int(_players.get(spot, VACANT))


func npc_at(spot: int) -> int:
	return int(_npcs.get(spot, VACANT))


## Take `spot` for `peer`. False if anybody else holds it. A peer moving to another
## spot gives up the first.
func take_for_player(peer: int, spot: int) -> bool:
	if player_at(spot) == peer:
		return true
	if not is_vacant(spot):
		return false
	release_player(peer)
	_players[spot] = peer
	_by_peer[peer] = spot
	return true


func release_player(peer: int) -> void:
	if _by_peer.has(peer):
		_players.erase(_by_peer[peer])
		_by_peer.erase(peer)


## Take `spot` for NPC `index`. False if anybody else holds it.
func take_for_npc(index: int, spot: int) -> bool:
	if npc_at(spot) == index:
		return true
	if not is_vacant(spot):
		return false
	release_npc(index)
	_npcs[spot] = index
	_by_npc[index] = spot
	return true


func release_npc(index: int) -> void:
	if _by_npc.has(index):
		_npcs.erase(_by_npc[index])
		_by_npc.erase(index)


## A vacant spot chosen from `rng` among `count`, or `VACANT` when every one is held.
## **Uniform over the vacant ones**, so a market with one free counter fills it rather
## than an NPC giving up after a few unlucky draws.
func a_vacant_spot(rng: RandomNumberGenerator, count: int) -> int:
	var free := PackedInt32Array()
	for spot: int in count:
		if is_vacant(spot):
			free.append(spot)
	if free.is_empty() or rng == null:
		return VACANT
	return free[rng.randi_range(0, free.size() - 1)]


## How many spots NPCs hold, for the census.
func held_by_npcs() -> int:
	return _npcs.size()


func clear() -> void:
	_players.clear()
	_npcs.clear()
	_by_peer.clear()
	_by_npc.clear()
