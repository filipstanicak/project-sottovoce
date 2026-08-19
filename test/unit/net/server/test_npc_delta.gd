## **ONLY THE CROWD RECORDS THAT CHANGED GO ON THE WIRE.** US-0031, TDD-04 §7.1.2.
##
## **THE COUNTERFACTUAL COMES FIRST AND IT IS THE WHOLE FILE.** "Unchanged records
## are omitted" is perfectly true of a delta that omits *everything*, and of one
## that omits nothing while a crowd happens to move every tick. Both would pass a
## test that only counted bytes. So the first test requires a standing NPC to be
## dropped **and** a walking one to survive, in the same tick.
##
## **THE ACK IS THE THING THAT IS EASY TO GET WRONG.** Snapshots are unreliable, so
## *sent* says nothing about *arrived*: a baseline that advanced on transmission
## works perfectly until one packet drops and then omits that record forever,
## because the server believes the client holds a value it never received. US-0031
## learned that for remote pawns; this is the same lesson in the crowd block, and
## `test_a_dropped_snapshot_is_resent` is where it is asserted.
extends GutTest

const ALICE := 8801
const BOB := 8802


func _record(index: int, at: Vector3, yaw: float = 0.0, state: int = 1) -> Array:
	return [index, at, yaw, state, 0]


func _indices(records: Array) -> Array:
	var out: Array = []
	for record: Array in records:
		out.append(int(record[0]))
	out.sort()
	return out


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **A DELTA THAT DROPS EVERYTHING SAVES THE MOST BANDWIDTH AND BREAKS THE GAME.**
## Both halves are required in one assertion: the NPC that stood still must be
## gone, and the one that walked must still be there.
func test_a_standing_npc_is_dropped_and_a_walking_one_is_not() -> void:
	var delta := NpcDelta.new()
	var still := _record(1, Vector3(10.0, 0.0, 10.0))
	var walker := _record(2, Vector3(20.0, 0.0, 20.0))
	assert_eq(_indices(delta.changed(ALICE, 1, [still, walker])), [1, 2], "the first tick is full")
	delta.note_ack(ALICE, 1)

	var moved := _record(2, Vector3(21.0, 0.0, 20.0))
	var sent := delta.changed(ALICE, 2, [still, moved])
	assert_eq(_indices(sent), [2], "the standing NPC survived, or the walking one was dropped")


## The saving is real only if a settled crowd costs nothing at all. Asserted
## separately from the mixed case above, because "some records were dropped" and
## "an unchanged crowd is free" are different claims.
func test_a_settled_crowd_costs_nothing() -> void:
	var delta := NpcDelta.new()
	var crowd: Array = []
	for index: int in 20:
		crowd.append(_record(index, Vector3(float(index), 0.0, 0.0)))
	assert_eq(delta.changed(ALICE, 1, crowd).size(), 20, "the first tick must be full")
	delta.note_ack(ALICE, 1)
	assert_eq(delta.changed(ALICE, 2, crowd).size(), 0, "a motionless crowd still cost bytes")


# ---------------------------------------------------------------------------
# The ack.
# ---------------------------------------------------------------------------


## **THE BASELINE IS WHAT THE CLIENT ACKNOWLEDGED, NEVER WHAT WAS LAST SENT.** A
## snapshot that never arrived must be sent again; a baseline that advanced on
## transmission would omit that record from then on, and the client would hold a
## stale NPC forever with nothing anywhere reporting it. This is the single most
## important assertion in the file.
func test_a_dropped_snapshot_is_resent() -> void:
	var delta := NpcDelta.new()
	var one := _record(1, Vector3(10.0, 0.0, 10.0))
	delta.changed(ALICE, 1, [one])
	# No ack for tick 1: the packet was lost. The record is still owed.
	assert_eq(
		_indices(delta.changed(ALICE, 2, [one])),
		[1],
		"a record the client never acknowledged was dropped as already-held"
	)


## An ack promotes only what was sent at or before it. A record still in flight
## stays in flight — promoting it early is the same bug as delta-ing against sent.
func test_an_ack_promotes_only_what_it_could_have_carried() -> void:
	var delta := NpcDelta.new()
	delta.changed(ALICE, 1, [_record(1, Vector3(1.0, 0.0, 0.0))])
	delta.changed(ALICE, 5, [_record(2, Vector3(2.0, 0.0, 0.0))])
	delta.note_ack(ALICE, 1)
	assert_eq(delta.confirmed_count(ALICE), 1, "the ack promoted a record it could not have held")
	assert_eq(delta.in_flight_count(ALICE), 1, "the later record was promoted or lost")
	delta.note_ack(ALICE, 5)
	assert_eq(delta.confirmed_count(ALICE), 2, "the second ack promoted nothing")


## **A CULLED OR RATE-SKIPPED NPC IS NOT A CHANGED ONE.** An NPC simply not offered
## this tick must leave the baseline exactly as it was, or it would be re-sent the
## moment it came back into range — which is most of what rate LOD does, and would
## undo the saving it exists for.
func test_an_npc_that_was_not_offered_keeps_its_baseline() -> void:
	var delta := NpcDelta.new()
	var far := _record(7, Vector3(60.0, 0.0, 0.0))
	delta.changed(ALICE, 1, [far])
	delta.note_ack(ALICE, 1)
	for tick: int in range(2, 6):
		assert_eq(delta.changed(ALICE, tick, []).size(), 0, "an empty offer produced records")
	assert_eq(
		delta.changed(ALICE, 6, [far]).size(),
		0,
		"an NPC that was merely skipped was re-sent when it came back"
	)


# ---------------------------------------------------------------------------
# Per peer.
# ---------------------------------------------------------------------------


## Two clients hold different crowds, because culling is per observer. Sharing a
## baseline would omit from one client a record only the other ever received.
func test_peers_do_not_share_a_baseline() -> void:
	var delta := NpcDelta.new()
	var one := _record(1, Vector3(10.0, 0.0, 10.0))
	delta.changed(ALICE, 1, [one])
	delta.note_ack(ALICE, 1)
	assert_eq(delta.changed(ALICE, 2, [one]).size(), 0, "Alice was re-sent a record she holds")
	assert_eq(delta.changed(BOB, 2, [one]).size(), 1, "Bob was denied a record he never received")


## **ENet REUSES PEER IDS**, US-0037. A baseline left behind is inherited by the
## next joiner, who never received it — and whose crowd would then never be
## corrected, because every record they are missing is one the server believes
## they already have. Silent, and permanent for that match.
func test_a_departed_peer_leaves_no_baseline_behind() -> void:
	var delta := NpcDelta.new()
	var one := _record(1, Vector3(10.0, 0.0, 10.0))
	delta.changed(ALICE, 1, [one])
	delta.note_ack(ALICE, 1)
	delta.forget(ALICE)
	assert_eq(delta.confirmed_count(ALICE), 0, "a departed peer kept its baseline")
	assert_eq(delta.in_flight_count(ALICE), 0, "a departed peer kept records in flight")
	assert_eq(
		delta.changed(ALICE, 2, [one]).size(),
		1,
		"an inherited peer id was denied a record it never received"
	)


## **EQUAL FINGERPRINTS MUST SERIALISE IDENTICALLY**, or a record is dropped as
## unchanged while its bytes differ and the client draws a clone at a position the
## server never had. The same assertion `test_snapshot_delta.gd` makes for pawns,
## in the block that carries ninety times as many records.
func test_a_difference_the_wire_cannot_carry_is_not_a_difference() -> void:
	var below := _record(1, Vector3(10.0, 0.004, 10.0))
	var above := _record(1, Vector3(10.0, 0.0, 10.0))
	assert_eq(
		Snapshot.npc_fingerprint(below),
		Snapshot.npc_fingerprint(above),
		"a sub-quantum difference counted as a change; the crowd would resend forever"
	)
	var real := _record(1, Vector3(10.5, 0.0, 10.0))
	assert_ne(
		Snapshot.npc_fingerprint(above),
		Snapshot.npc_fingerprint(real),
		"half a metre did not count as a change; the crowd would freeze"
	)


## **ACKS LAG, AND EVERY OTHER TEST IN THIS FILE ACKNOWLEDGES INSTANTLY.** That is
## the one timing that hides the defect a live game showed: a record is re-sent
## while its first copy is still in flight, and if each re-send refreshes the
## stamp then the entry always leads the ack, is never promoted, and the NPC is
## sent **every tick for the rest of the match**.
##
## Measured on a running server before the fix: a motionless NPC at a constant
## 7.6122 m, sent on every one of twelve consecutive ticks. The delta was inert and
## the suite was green.
func test_the_delta_converges_when_the_ack_lags() -> void:
	var delta := NpcDelta.new()
	var still := _record(1, Vector3(10.0, 0.0, 10.0))
	var sends := 0
	for tick: int in range(1, 41):
		if not delta.changed(ALICE, tick, [still]).is_empty():
			sends += 1
		# The client acknowledges three ticks late, which is an ordinary RTT.
		if tick > 3:
			delta.note_ack(ALICE, tick - 3)
	assert_lt(
		sends,
		8,
		(
			(
				"a motionless NPC was sent %d times in 40 ticks. The delta never converges "
				+ "when the ack lags, which is every real connection."
			)
			% sends
		)
	)
	assert_gt(sends, 0, "nothing was ever sent, so this proves nothing")
