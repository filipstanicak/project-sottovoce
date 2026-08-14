## **WHO IS CONNECTED, WHO IS A PLAYER, AND WHAT THEY COST.** US-0025, US-0030.
##
## PURE. The roster, the wire slots and the RTT estimates in one object, so
## `Net` can stay what it is — the node that owns a socket and answers RPCs —
## rather than growing into the thing that also remembers everyone.
##
## It was extracted when `net.gd` crossed 400 lines, and the split it fell along
## is the honest one: **everything here is a fact about a peer, and everything
## left there is a message on a wire.**
##
## The three tables move together on purpose. A peer that leaves must lose its
## roster entry, its slot and its RTT in the same breath, because ENet reuses
## peer ids — anything left behind is inherited by the next joiner, and an
## inherited slot means the next player is named as the last one in every message
## that names anybody.
class_name PeerRegistry
extends RefCounted

var _players: Dictionary = {}
var _slots := SlotTable.new()
var _rtt := RttTable.new()


## Use the match's slot table rather than this object's own. Called once by the
## server, so that `MatchContext.slots` and the wire agree by construction rather
## than by two objects being kept in step.
func use_slots(table: SlotTable) -> void:
	if table != null:
		_slots = table


## Admit a peer and give it a wire identity. Returns `SlotTable.NO_SLOT` when the
## lobby is full, which the caller must treat as a refusal rather than as a zero.
func admit(peer: int) -> int:
	var slot := _slots.assign(peer)
	if slot == SlotTable.NO_SLOT:
		return SlotTable.NO_SLOT
	_players[peer] = true
	return slot


## Everything about `peer`, gone. Returns whether it had been a player, so the
## caller knows whether a departure is worth announcing.
func forget(peer: int) -> bool:
	var was_player: bool = _players.erase(peer)
	_slots.release(peer)
	_rtt.forget(peer)
	return was_player


func has_player(peer: int) -> bool:
	return _players.has(peer)


func player_count() -> int:
	return _players.size()


func slot_of(peer: int) -> int:
	return _slots.slot_of(peer)


func peer_of(slot: int) -> int:
	return _slots.peer_of(slot)


func record_rtt(peer: int, sample_ms: float) -> void:
	_rtt.record(peer, sample_ms)


func rtt_ms(peer: int) -> float:
	return _rtt.rtt_ms(peer)


func clear() -> void:
	_players.clear()
	_slots.clear()
	_rtt.clear()
