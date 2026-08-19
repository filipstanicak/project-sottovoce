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

## **THE CROWD IS CARRIED FORWARD, NOT KEYED BY TICK.** A remote pawn is offered
## every tick, so "which pawns did tick N hold" is a complete answer. An NPC is
## culled by distance (US-0030) and rate-limited by it (US-0031), so no single
## tick ever holds the whole crowd and a tick-keyed baseline would lose every NPC
## that happened not to be due. What the client holds is the newest record it has
## ever been given for each index, which is exactly what the server's `NpcDelta`
## believes it holds.
##
## **ABSENT MEANS "NO UPDATE", NEVER "GONE".** That is already true of culling and
## rate LOD, which is why the crowd block needed no `present_slots` and no protocol
## change. **The protocol still cannot say an NPC has LEFT** — nothing observes
## that yet, because there is no `NpcView`. TDD-04 §7.1.2.
var _crowd: Dictionary = {}

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
	snapshot.npcs = _carry_the_crowd_forward(snapshot)
	return snapshot


## Every NPC this client has ever been told about, updated with whatever this
## snapshot carried. A **full** snapshot does not reset it: fullness is a statement
## about the remote-pawn baseline, and the crowd's baseline is per NPC and advances
## on the ack, so a full snapshot still omits every unchanged NPC.
func _carry_the_crowd_forward(snapshot: Snapshot) -> Array:
	for record: Array in snapshot.npcs:
		_crowd[int(record[0])] = record
	return _crowd.values()


## How many distinct NPCs this client is holding. Diagnostics, and the one number
## that separates a working carry-forward from a snapshot that simply happened to
## contain everything.
func crowd_size() -> int:
	return _crowd.size()


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
	_crowd.clear()
	_newest = 0
	unappliable = 0
