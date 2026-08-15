## **A DELTA GOES IN, A COMPLETE SNAPSHOT COMES OUT.** TDD-04 §7.2, US-0031.
## CLIENT ONLY.
##
## PURE — snapshots in, snapshots out, no nodes and no autoloads.
##
## **DELTA ENCODING IS A WIRE CONCERN AND STOPS HERE.** `Net` assembles before it
## emits `snapshot_received`, so `RemotePawns`, `Reconciler` and everything above
## them are handed the same complete object they were handed before US-0031 and
## never learn that deltas exist. A partial snapshot escaping into gameplay code
## is the failure mode this shape exists to make impossible — one consumer would
## eventually read `remote_pawns` and treat "unchanged" as "gone".
##
## **AN UNAPPLIABLE DELTA IS DROPPED, NEVER GUESSED AT.** If the baseline is not
## in history the snapshot is refused outright. That is safe because the ack is
## driven from what was actually assembled: a dropped snapshot never becomes an
## ack, so the server keeps delta-ing against an older baseline this client does
## hold, or sends a full one. **The cost of loss is bandwidth, never correctness.**
class_name SnapshotAssembler
extends RefCounted

## Assembled ticks kept as potential baselines. The server holds 64 and its age
## byte tops out at 255; this is the same 64, because a baseline neither end
## still has is a full send either way.
const HISTORY := 64

## Snapshots refused for want of a baseline. Diagnostics only — but a number that
## climbs is the fingerprint of a server delta-ing against the wrong thing.
var unappliable: int = 0

## tick -> Array of complete remote-pawn records.
var _remotes: Dictionary = {}

var _newest: int = 0


## The newest tick successfully assembled. **This is what gets acknowledged**, and
## it is deliberately not "the newest tick received": acknowledging a snapshot we
## could not apply would tell the server to delta against a baseline we do not
## have, and the error would never converge.
func newest_tick() -> int:
	return _newest


## Complete `snapshot`, or `null` if its baseline is gone.
##
## A full snapshot always assembles. A delta is merged onto its baseline: records
## it carries replace theirs, records it omits are inherited unchanged, and
## **`present_slots` decides who exists at all** — an inherited record for a slot
## no longer present is dropped, which is what stops a player who disconnected
## while standing still from being inherited forever.
func assemble(snapshot: Snapshot) -> Snapshot:
	if snapshot == null:
		return null
	if snapshot.baseline_age != Snapshot.FULL:
		var baseline_tick := snapshot.server_tick - snapshot.baseline_age
		if not _remotes.has(baseline_tick):
			unappliable += 1
			return null
		snapshot.remote_pawns = _merge(_remotes[baseline_tick], snapshot)

	_remember(snapshot)
	return snapshot


## Baseline records, overwritten by the delta's, filtered to who is present.
func _merge(baseline: Array, delta: Snapshot) -> Array:
	var by_slot: Dictionary = {}
	for record: Array in baseline:
		by_slot[int(record[0])] = record
	for record: Array in delta.remote_pawns:
		by_slot[int(record[0])] = record

	var out: Array = []
	for slot: int in by_slot:
		if _is_present(delta.present_slots, slot):
			out.append(by_slot[slot])
	return out


## Bit `n` of the mask is slot `n + 1`. Slot 0 is `SlotTable.NO_SLOT` and is
## never present.
static func _is_present(mask: int, slot: int) -> bool:
	if slot <= 0 or slot > 8:
		return false
	return (mask & (1 << (slot - 1))) != 0


## **OUT-OF-ORDER SNAPSHOTS DO NOT WALK THE ACK BACKWARDS.** The `STATE` channel
## is unordered, so an older snapshot can arrive after a newer one. It is still
## stored — it is a legitimate baseline the server may reference — but it must not
## become the acknowledged tick, or the server would start sending deltas against
## a baseline older than the one this client already has.
func _remember(snapshot: Snapshot) -> void:
	_remotes[snapshot.server_tick] = snapshot.remote_pawns.duplicate()
	_newest = maxi(_newest, snapshot.server_tick)
	for tick: int in _remotes.keys():
		if _newest - tick >= HISTORY:
			_remotes.erase(tick)


## Reset between matches, and on disconnect. A baseline surviving a reconnect
## would be applied to a different match's ticks.
func clear() -> void:
	_remotes.clear()
	_newest = 0
	unappliable = 0
