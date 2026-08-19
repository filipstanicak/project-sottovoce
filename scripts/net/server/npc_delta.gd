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


## Remember what went out, against the **earliest** tick that carried this value.
##
## **KEEPING THE LATEST TICK MADE THE WHOLE DELTA INERT, AND ONLY A LIVE GAME
## SHOWED IT.** An ack lags by at least a tick, so a record is re-sent while its
## first copy is still in flight — and overwriting the stamp each time means the
## entry always leads the ack, is never promoted, and the NPC is therefore sent
## **every single tick for the rest of the match**. Measured on a running server:
## a motionless NPC at a constant 7.6122 m, sent on every one of twelve consecutive
## ticks.
##
## Every unit test acknowledged synchronously, one tick after the send, which is
## the one timing that hides this. **A delta that reports a saving it does not
## deliver is the exact failure this class's own docstring warns about**, two
## paragraphs up, about tick-keyed baselines.
##
## The client only has to receive a value once, so the earliest send is the one an
## ack should clear. A *changed* value resets the stamp, because that is a
## different thing to have received.
func _note_sent(peer: int, tick: int, sent: Array) -> void:
	if not _in_flight.has(peer):
		_in_flight[peer] = {}
	var pending: Dictionary = _in_flight[peer]
	for record: Array in sent:
		var index := int(record[0])
		var print_of := Snapshot.npc_fingerprint(record)
		var already: Variant = pending.get(index)
		if already != null and (already as Array)[1] == print_of:
			continue
		pending[index] = [tick, print_of]


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


## Does this peer hold anything for `index` — confirmed or still in flight?
##
## **THE SERVER HAS TO SAY GOODBYE, BECAUSE ABSENCE CANNOT.** A client is told
## nothing about a culled NPC, and the last position it *was* told is inside the
## radius by definition, so its own distance check can never fire: the NPC is
## drawn frozen at the boundary forever. `SnapshotBuilder` sends one final record
## carrying the real out-of-range position, and this is how it knows which NPCs
## the client is actually holding and therefore owes a farewell to.
func holds(peer: int, index: int) -> bool:
	if (_confirmed.get(peer, {}) as Dictionary).has(index):
		return true
	return (_in_flight.get(peer, {}) as Dictionary).has(index)


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
