## **PEER IDS ARE 32 BITS. THE PROTOCOL SAYS `u8`.** NETWORK_PROTOCOL §3–4,
## US-0029.
##
## Godot hands out a random 32-bit id per peer — a real one from a test run was
## **1 526 710 570** — and the catalogue declares `peer_id:u8` in seven places:
## the snapshot's remote-pawn record, `NET-S2C-WELCOME`, `-PLAYER-JOINED`,
## `-CONTRACT-ASSIGNED`, `-KILL-RESULT`, `-STUN-RESULT` and `-SCORE-EVENT`.
##
## **THE CATALOGUE IS RIGHT AND THE ENGINE IS THE ANOMALY.** A match holds at
## most `TUN-LOBBY-MAX-PLAYERS` 6 players, so a player fits in three bits with
## room to spare, and the byte is what the bandwidth budget was written against:
## the remote-pawn record appears five times per snapshot at 30 Hz, and every
## entity id in the crowd payload is a byte for the same reason. Sending the raw
## id instead costs three extra bytes per record — about 8.6 kB/s per client
## against a 12 kB/s budget that is already at 87 %.
##
## So the server keeps a mapping, and **the raw peer id never reaches the wire**.
## That is a second benefit worth having: a slot number carries no information
## about the transport, and one match's slot 2 tells an observer nothing about
## the next match's.
##
## PURE. The allocation rule is arithmetic on a dictionary, and it decides who is
## replicable — so it is tested with no peer, no socket and no snapshot.
class_name SlotTable
extends RefCounted

## Reserved. **A SLOT OF ZERO IS "NOBODY"**, so a record that was never filled
## in decodes as absent rather than as player one — which is the difference
## between a bug that shows and a bug that names the wrong killer.
const NO_SLOT := 0

const FIRST_SLOT := 1

var _slot_for: Dictionary = {}
var _peer_for: Dictionary = {}


## Give `peer` a slot, or return the one it already has. Idempotent, because a
## peer that reconnects inside one match must not consume two.
func assign(peer: int) -> int:
	if _slot_for.has(peer):
		return _slot_for[peer]
	var slot := _lowest_free()
	if slot == NO_SLOT:
		return NO_SLOT
	_slot_for[peer] = slot
	_peer_for[slot] = peer
	return slot


## **THE LOWEST FREE SLOT, NOT THE NEXT ONE.** A counter that only ever counted
## up would exhaust the byte after 255 joins in a long-lived server, and would do
## it silently — the 256th player would be slot 0, which means nobody.
func _lowest_free() -> int:
	var ceiling: int = Tuning.match_rules.max_players
	for candidate: int in range(FIRST_SLOT, ceiling + 1):
		if not _peer_for.has(candidate):
			return candidate
	return NO_SLOT


func release(peer: int) -> void:
	if not _slot_for.has(peer):
		return
	_peer_for.erase(_slot_for[peer])
	_slot_for.erase(peer)


func slot_of(peer: int) -> int:
	return _slot_for.get(peer, NO_SLOT)


func peer_of(slot: int) -> int:
	return _peer_for.get(slot, 0)


func has_peer(peer: int) -> bool:
	return _slot_for.has(peer)


func count() -> int:
	return _slot_for.size()


func clear() -> void:
	_slot_for.clear()
	_peer_for.clear()
