## **WHAT EACH CLIENT ALREADY HAS, AND THEREFORE WHAT NOT TO SEND AGAIN.**
## TDD-04 §7.2 mechanism 3, US-0031. SERVER ONLY.
##
## PURE — records in, records out. It holds no peers, no sockets and no snapshot
## builder, so every question about what a delta omits can be asked directly
## rather than by standing a server up.
##
## **THE BASELINE IS WHAT THE CLIENT ACKNOWLEDGED, NEVER WHAT WE LAST SENT.**
## Snapshots ride the unreliable `STATE` channel, so "sent" says nothing about
## "arrived". Delta-ing against the last *sent* snapshot is the classic version of
## this bug: it works perfectly until one packet is dropped, and from then on
## every subsequent delta is applied to a baseline the client does not have. The
## symptom is a remote player frozen or teleporting, on a connection that looks
## healthy, and it does not reproduce on a LAN.
##
## **A LOST ACK COSTS BANDWIDTH, NEVER CORRECTNESS.** If the client's
## acknowledged tick stops advancing, this keeps delta-ing against that older
## baseline — which the client demonstrably has, because it acknowledged it — and
## the deltas simply grow. Past `Snapshot.MAX_BASELINE_AGE`, or with no ack at
## all, it answers `FULL` and the whole world is sent. There is no path here that
## produces a delta the client cannot apply.
class_name SnapshotDelta
extends RefCounted

## Ticks of sent snapshots kept per peer. Slightly over
## `Snapshot.MAX_BASELINE_AGE` would be pointless — the age byte cannot express
## a baseline older than 255 — and this is 64, about two seconds at 30 Hz, which
## is far longer than any client that is still connected will take to acknowledge.
const HISTORY := 64

## peer -> { tick: Array of fingerprints keyed by slot }
var _sent: Dictionary = {}

## peer -> the newest tick this peer has told us it received.
var _acked: Dictionary = {}


## The client says which tick it has. Carried by `NET-C2S-INPUT`'s `acked_tick`.
##
## **MONOTONIC.** `InputCommand`s arrive unordered on an unreliable channel, so a
## stale one carrying an older ack must not walk the baseline backwards — that
## would be harmless for correctness and would silently double the delta size for
## as long as it kept happening.
func note_ack(peer: int, tick: int) -> void:
	if tick <= 0:
		return
	_acked[peer] = maxi(int(_acked.get(peer, 0)), tick)


func acked_tick(peer: int) -> int:
	return int(_acked.get(peer, 0))


## Store the fingerprints of what was sent to `peer` at `tick`.
func remember(peer: int, tick: int, records: Array) -> void:
	if not _sent.has(peer):
		_sent[peer] = {}
	var by_tick: Dictionary = _sent[peer]
	var by_slot: Dictionary = {}
	for record: Array in records:
		by_slot[int(record[0])] = Snapshot.remote_fingerprint(record)
	by_tick[tick] = by_slot
	_prune(by_tick, tick)


func _prune(by_tick: Dictionary, newest: int) -> void:
	for tick: int in by_tick.keys():
		if newest - tick >= HISTORY:
			by_tick.erase(tick)


## How many ticks back `peer`'s baseline is, or `Snapshot.FULL` if there is none
## usable and the whole world must be sent.
func baseline_age(peer: int, tick: int) -> int:
	var acked := acked_tick(peer)
	if acked <= 0 or acked >= tick:
		return Snapshot.FULL
	var age := tick - acked
	if age > Snapshot.MAX_BASELINE_AGE or _baseline(peer, acked) == null:
		return Snapshot.FULL
	return age


## The records `peer` should actually be sent this tick: every one whose
## **quantised** form differs from the baseline, and every one the baseline had
## never heard of.
##
## A record identical to the baseline is dropped. That is the whole saving, and
## §7.1 budgets it at 45 % of the crowd standing still — which is why a *player*
## delta buys so little at M2 and the measurement waits for M3.
func changed(peer: int, tick: int, records: Array) -> Array:
	var age := baseline_age(peer, tick)
	if age == Snapshot.FULL:
		return records.duplicate()
	var baseline: Dictionary = _baseline(peer, tick - age)
	var out: Array = []
	for record: Array in records:
		var slot := int(record[0])
		if not baseline.has(slot) or baseline[slot] != Snapshot.remote_fingerprint(record):
			out.append(record)
	return out


func _baseline(peer: int, tick: int) -> Variant:
	var by_tick: Dictionary = _sent.get(peer, {})
	return by_tick.get(tick, null)


## **EVERY OWNER OF PER-PEER STATE IS TOLD WHEN A PEER LEAVES**, US-0037. ENet
## reuses peer ids, so a baseline left behind would be delta-ed against by the
## next joiner — who never received it, and whose remote pawns would then be
## assembled from somebody else's past.
func forget(peer: int) -> void:
	_sent.erase(peer)
	_acked.erase(peer)


## Peers with bookkeeping. For the churn test's baseline count.
func tracked_peers() -> int:
	return _sent.size()
