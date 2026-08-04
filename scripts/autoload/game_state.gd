## Client-side read-only mirror of match phase, local peer and lobby roster.
##
## WRITTEN ONLY BY NET. Everything else reads.
##
## The one-writer rule is the whole value of this object. The moment a second
## system can write here, "what phase are we in" has two answers depending on
## when you ask, and the bug that follows is a HUD disagreeing with the server —
## which the never-do list calls worse than no HUD at all.
##
## `test_game_state_single_writer.gd` asserts it, because the rule is a
## convention that nothing in the language enforces.
extends Node

## Emitted after any mutation, so a view model never polls.
signal state_replaced

enum Phase { LOBBY, WARMUP, ACTIVE, FINAL, RESULTS }

var local_peer_id: int = 0
var phase: Phase = Phase.LOBBY

## peer id -> display name. The roster is identity ONLY: no persona, no score, no
## suspicion. Anything anonymity-sensitive stays server-side, and a client that
## never receives it cannot leak it.
var roster: Dictionary = {}


func is_lobby() -> bool:
	return phase == Phase.LOBBY


func is_playing() -> bool:
	return phase == Phase.ACTIVE or phase == Phase.FINAL


func peer_count() -> int:
	return roster.size()


func has_peer(peer: int) -> bool:
	return roster.has(peer)


## Replace everything at once. One entry point rather than a settable property
## per field, so a partially-applied update is not expressible.
func replace(new_peer_id: int, new_phase: Phase, new_roster: Dictionary) -> void:
	local_peer_id = new_peer_id
	phase = new_phase
	roster = new_roster.duplicate(true)
	state_replaced.emit()


## Reset to lobby. Called on disconnect, so a stale roster never outlives the
## session that produced it.
func clear() -> void:
	replace(0, Phase.LOBBY, {})
