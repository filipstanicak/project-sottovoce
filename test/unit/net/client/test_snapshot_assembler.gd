## **A DELTA GOES IN, A WHOLE SNAPSHOT COMES OUT.** US-0031, TDD-04 §7.2.
##
## The client half. `test_snapshot_delta.gd` proves what the server omits; this
## proves the omission is recoverable — and, more importantly, that an
## unrecoverable one is **dropped rather than guessed at.**
extends GutTest

## Slots 1 and 2 present.
const BOTH := 0b11

var _assembler: SnapshotAssembler


func before_each() -> void:
	_assembler = SnapshotAssembler.new()


func _snapshot(tick: int, age: int, records: Array, present: int) -> Snapshot:
	var snap := Snapshot.new()
	snap.server_tick = tick
	snap.baseline_age = age
	snap.remote_pawns = records
	snap.present_slots = present
	return snap


func _record(slot: int, z: float) -> Array:
	return [slot, Vector3(0.0, 0.0, z), 0.0, PawnStateId.STROLL, 0, 0]


func test_a_full_snapshot_always_assembles() -> void:
	var out := _assembler.assemble(
		_snapshot(10, Snapshot.FULL, [_record(1, 1.0), _record(2, 2.0)], BOTH)
	)
	assert_not_null(out, "a full snapshot did not assemble")
	assert_eq(out.remote_pawns.size(), 2, "a full snapshot lost a record")
	assert_eq(_assembler.newest_tick(), 10, "the assembled tick was not recorded")


func test_an_omitted_record_is_inherited_from_the_baseline() -> void:
	# **THE SAVING, RECOVERED.** Slot 1 stood still and was not sent; the client
	# must still know where it is.
	_assembler.assemble(_snapshot(10, Snapshot.FULL, [_record(1, 1.0), _record(2, 2.0)], BOTH))
	var out := _assembler.assemble(_snapshot(11, 1, [_record(2, 9.0)], BOTH))

	assert_not_null(out, "a delta with a held baseline did not assemble")
	assert_eq(out.remote_pawns.size(), 2, "the inherited record is missing")
	var by_slot: Dictionary = {}
	for record: Array in out.remote_pawns:
		by_slot[int(record[0])] = record
	assert_eq((by_slot[1][1] as Vector3).z, 1.0, "slot 1 did not keep its baseline position")
	assert_eq((by_slot[2][1] as Vector3).z, 9.0, "slot 2 did not take the delta's position")


func test_a_delta_whose_baseline_is_gone_is_dropped_not_guessed() -> void:
	# **THE ASSERTION THE FILE IS FOR.** Assembling against a baseline we do not
	# have would produce a plausible, wrong world. Refusing costs one frame, and
	# the ack does not advance — so the server keeps using an older baseline this
	# client holds, or sends a full snapshot. The cost of loss is bandwidth.
	var out := _assembler.assemble(_snapshot(11, 1, [_record(2, 9.0)], BOTH))
	assert_null(out, "a delta was assembled against a baseline that was never received")
	assert_eq(_assembler.unappliable, 1, "the unappliable snapshot was not counted")


func test_a_dropped_snapshot_does_not_become_an_ack() -> void:
	# If it did, the server would delta against a baseline this client never
	# assembled and the error would never converge — the one failure mode the
	# whole ack design exists to prevent.
	_assembler.assemble(_snapshot(10, Snapshot.FULL, [_record(1, 1.0)], 0b1))
	_assembler.assemble(_snapshot(30, 5, [_record(1, 5.0)], 0b1))
	assert_eq(_assembler.newest_tick(), 10, "a snapshot that could not be applied was acknowledged")


func test_a_slot_that_vanishes_is_not_inherited_forever() -> void:
	# **THE DEFECT `present_slots` EXISTS TO PREVENT.** Before delta encoding,
	# "absent from the snapshot" meant "gone". Now it means "unchanged" — so a
	# player who disconnects while standing still is omitted for being unchanged
	# and would stand in the district for the rest of the match.
	_assembler.assemble(_snapshot(10, Snapshot.FULL, [_record(1, 1.0), _record(2, 2.0)], BOTH))
	var out := _assembler.assemble(_snapshot(11, 1, [], 0b1))

	assert_eq(out.remote_pawns.size(), 1, "a departed slot was inherited from the baseline")
	assert_eq(int(out.remote_pawns[0][0]), 1, "the wrong slot survived")


func test_an_out_of_order_snapshot_does_not_walk_the_ack_backwards() -> void:
	# The STATE channel is unordered. An older snapshot arriving late is still a
	# legitimate baseline and is kept, but acknowledging it would ask the server
	# to delta against something staler than this client already has.
	_assembler.assemble(_snapshot(10, Snapshot.FULL, [_record(1, 1.0)], 0b1))
	_assembler.assemble(_snapshot(20, Snapshot.FULL, [_record(1, 2.0)], 0b1))
	_assembler.assemble(_snapshot(15, Snapshot.FULL, [_record(1, 3.0)], 0b1))
	assert_eq(_assembler.newest_tick(), 20, "a late snapshot walked the acknowledged tick back")


func test_a_chain_of_deltas_stays_correct() -> void:
	# Each delta's baseline is the previous assembled tick, which is what a
	# healthy connection actually produces.
	_assembler.assemble(_snapshot(1, Snapshot.FULL, [_record(1, 0.0), _record(2, 0.0)], BOTH))
	for tick: int in range(2, 12):
		_assembler.assemble(_snapshot(tick, 1, [_record(2, float(tick))], BOTH))

	var out := _assembler.assemble(_snapshot(12, 1, [], BOTH))
	var by_slot: Dictionary = {}
	for record: Array in out.remote_pawns:
		by_slot[int(record[0])] = record
	assert_eq((by_slot[1][1] as Vector3).z, 0.0, "the never-moving slot drifted across the chain")
	assert_eq((by_slot[2][1] as Vector3).z, 11.0, "the moving slot lost its last update")


func test_history_does_not_grow_without_bound() -> void:
	for tick: int in range(1, SnapshotAssembler.HISTORY + 40):
		_assembler.assemble(_snapshot(tick, Snapshot.FULL, [_record(1, float(tick))], 0b1))
	# The oldest baselines must be gone, or a client holds the whole match.
	var stale := _assembler.assemble(_snapshot(SnapshotAssembler.HISTORY + 40, 100, [], 0b1))
	assert_null(stale, "a baseline older than the history was still held")


## **A DEPARTED NPC MUST STOP BEING CARRIED FORWARD.** US-0045, TDD-04 §7.1.3.
##
## The crowd is carried forward because absence means "no update" — and the one
## record that does NOT mean that is the farewell: a position beyond
## `TUN-NET-NPC-CULL-RADIUS`, which the server sends once and never repeats,
## because it has just discarded that NPC's baseline.
##
## Carrying it forward replays that goodbye in every snapshot for the rest of the
## match. Measured on a running server: one NPC re-presented at a constant
## **70.0231 m on 199 consecutive ticks**, each of which made `NpcView` create a
## body and immediately free it.
func test_a_farewell_is_delivered_once_and_then_forgotten() -> void:
	var here := Vector3.ZERO
	var reach: float = Tuning.net.npc_cull_radius
	_assembler.assemble(_crowd_snapshot(10, here, [Vector3(reach - 5.0, 0.0, 0.0)]))
	var goodbye := _assembler.assemble(_crowd_snapshot(11, here, [Vector3(reach + 2.0, 0.0, 0.0)]))

	assert_eq(goodbye.npcs.size(), 1, "the farewell itself was not delivered")
	assert_eq(_assembler.crowd_size(), 0, "a departed NPC is still being carried forward")

	var after := _assembler.assemble(_crowd_snapshot(12, here, []))
	assert_eq(
		after.npcs.size(),
		0,
		(
			"the farewell was replayed. The server sends one and never repeats it, so "
			+ "every later snapshot is telling the client to say goodbye again."
		)
	)


## **AND AN NPC MERELY OUT OF DATE IS NOT A DEPARTURE.** The carry-forward exists
## for exactly this: culling, rate LOD and the delta all omit NPCs the client must
## keep drawing. A rule that forgot a record for being stale rather than for being
## a farewell would empty the crowd instead of trimming it.
func test_an_unmentioned_npc_is_still_carried_forward() -> void:
	var here := Vector3.ZERO
	_assembler.assemble(_crowd_snapshot(10, here, [Vector3(20.0, 0.0, 0.0)]))
	var later := _assembler.assemble(_crowd_snapshot(11, here, []))

	assert_eq(later.npcs.size(), 1, "an NPC omitted for being unchanged was lost")
	assert_eq(_assembler.crowd_size(), 1, "the carry-forward dropped a live NPC")


func _crowd_snapshot(tick: int, observer: Vector3, spots: Array) -> Snapshot:
	var snap := Snapshot.new()
	snap.server_tick = tick
	snap.baseline_age = Snapshot.FULL
	snap.own_position = observer
	for index: int in spots.size():
		snap.add_npc(index, observer + (spots[index] as Vector3), 0.0, 1, 0)
	return snap


func test_clear_forgets_everything() -> void:
	# A baseline surviving a reconnect would be applied to a different match's
	# ticks — the same inheritance failure as a stale wire slot.
	_assembler.assemble(_snapshot(10, Snapshot.FULL, [_record(1, 1.0)], 0b1))
	_assembler.clear()
	assert_eq(_assembler.newest_tick(), 0, "clear left an acknowledged tick behind")
	assert_null(_assembler.assemble(_snapshot(11, 1, [], 0b1)), "clear left a baseline behind")
