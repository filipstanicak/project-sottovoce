## **WHICH CROWD RECORDS A CLIENT ALREADY HOLDS.** US-0031, TDD-04 §7.1.2.
## SERVER ONLY, and PURE — records in, a subset out, no socket and no node.
##
## **IT CANNOT BE `SnapshotDelta` AND THE REASON IS RATE LOD.** That class keeps
## one baseline per *tick* and compares this tick's whole record set against it,
## which is right for remote pawns: every pawn is offered every tick, so absence
## from the baseline means the client genuinely has nothing. An NPC past
## `TUN-NET-NPC-RATE-LOD-RADIUS` is only *considered* on one tick in three, so it
## is missing from almost every tick's baseline through no fault of the client —
## and a tick-keyed comparison would call it "new" every single time and send it,
## which is a delta that saves nothing while reporting that it works.
##
## **SO THE BASELINE IS PER NPC, NOT PER TICK**, and it advances on acknowledgement
## rather than on transmission. Snapshots are unreliable: *sent* says nothing about
## *arrived*, and delta-ing against the last thing sent works perfectly until one
## packet drops and then corrupts every frame after it — on a connection that looks
## healthy, and never on a LAN. US-0031 learned that once already for remote pawns.
##
## **ABSENT MEANS "NO UPDATE", NOT "GONE", AND THAT WAS ALREADY TRUE.** Culling
## (US-0030) and rate LOD both omit NPCs the client must keep drawing, so the
## crowd block had those semantics before this class existed — which is why an NPC
## delta needs no protocol change, where the remote-pawn one needed
## `present_slots`. **What the protocol still cannot say is that an NPC has LEFT.**
## Nothing observes that yet, because there is no `NpcView`; it is recorded in
## TDD-04 §7.1.2 rather than invented here.
class_name NpcDelta
extends RefCounted

var _confirmed: Dictionary = {}
var _in_flight: Dictionary = {}


## The records `peer` should actually be sent, out of the ones offered this tick.
func changed(peer: int, tick: int, offered: Array) -> Array:
	var known: Dictionary = _confirmed.get(peer, {})
	var out: Array = []
	for record: Array in offered:
		var index := int(record[0])
		var print_of := Snapshot.npc_fingerprint(record)
		if not known.has(index) or known[index] != print_of:
			out.append(record)
	_note_sent(peer, tick, out)
	return out


## Remember what went out, against the tick that carried it, so an ack can promote
## it later. Only records actually sent are remembered — one that was dropped as
## unchanged is already accounted for by the entry it matched.
func _note_sent(peer: int, tick: int, sent: Array) -> void:
	if not _in_flight.has(peer):
		_in_flight[peer] = {}
	var pending: Dictionary = _in_flight[peer]
	for record: Array in sent:
		pending[int(record[0])] = [tick, Snapshot.npc_fingerprint(record)]


## **EVERYTHING SENT AT OR BEFORE `tick` IS NOW KNOWN TO HAVE ARRIVED.** Connected
## to the same ack the remote-pawn delta uses, so both halves of a snapshot advance
## on the same evidence.
##
## A record still in flight stays in flight: promoting it early is exactly the bug
## that makes a dropped packet permanent, because the server would then believe the
## client holds a value it never received and would never send it again.
func note_ack(peer: int, tick: int) -> void:
	var pending: Dictionary = _in_flight.get(peer, {})
	if pending.is_empty():
		return
	if not _confirmed.has(peer):
		_confirmed[peer] = {}
	var known: Dictionary = _confirmed[peer]
	for index: int in pending.keys():
		var entry: Array = pending[index]
		if int(entry[0]) <= tick:
			known[index] = entry[1]
			pending.erase(index)


## **AN NPC THE CLIENT CAN NO LONGER SEE IS AN NPC IT NO LONGER HOLDS.** Called
## with everything the cull removed this tick, because **culling and the delta
## together lose an NPC permanently and neither is wrong on its own.**
##
## A standing NPC that a player walks away from and back to left the snapshot
## because it was culled; its baseline survived the cull; and on return its record
## is byte-identical to the one this class believes the client holds, so it is
## dropped as already-held and **never mentioned again**. The client cannot cover
## for it: absence is its only signal, so it must discard what leaves its own cull
## radius, and it is then missing an NPC forever.
##
## The idle case is the common one rather than a corner — NPCs stand at anchors
## for `TUN-CROWD-IDLE-DURATION-MIN..MAX`, so "the NPC did not move, the player
## did" is most of a match.
##
## **RATE-SKIPPED NPCs MUST NOT COME THROUGH HERE.** One that is merely not due
## this tick is still in view and still held; forgetting it would re-send the far
## band at full rate and undo exactly what US-0031 built.
func drop(peer: int, indices: PackedInt32Array) -> void:
	var known: Dictionary = _confirmed.get(peer, {})
	var pending: Dictionary = _in_flight.get(peer, {})
	for index: int in indices:
		known.erase(index)
		pending.erase(index)


## How many NPCs this peer is believed to hold. For tests and for the wire-cost
## measurement, which otherwise cannot tell a working delta from an inert one.
func confirmed_count(peer: int) -> int:
	return int((_confirmed.get(peer, {}) as Dictionary).size())


func in_flight_count(peer: int) -> int:
	return int((_in_flight.get(peer, {}) as Dictionary).size())


## **EVERY OWNER OF PER-PEER STATE IS TOLD WHEN A PEER LEAVES**, US-0037. ENet
## reuses peer ids, so a baseline left behind would be inherited by the next
## joiner — who never received it, and whose crowd would then be assembled from
## somebody else's past and would simply never be corrected, because every record
## it is missing is one the server believes it already has.
func forget(peer: int) -> void:
	_confirmed.erase(peer)
	_in_flight.erase(peer)


func tracked_peers() -> int:
	return _confirmed.size()
