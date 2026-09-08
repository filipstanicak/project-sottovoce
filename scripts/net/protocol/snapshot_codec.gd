## Ordered snapshot encoding, decoding and quantised fingerprints. NETWORK_PROTOCOL section 4.
## Keep writers and readers together: field order, widths and quantisation ARE the wire.
## Snapshot retains the public value/API surface; this codec adds no fields or state.
class_name SnapshotCodec
extends RefCounted


## **EXACTLY WHAT `_write_remotes` WOULD PUT ON THE WIRE**, as comparable values.
##
## Delta encoding omits a record whose state is unchanged, and §7.2 is precise
## about which state: the **quantised** one. Comparing the `Vector3`s instead
## would be wrong in both directions — two positions 3 mm apart round to the same
## centimetre and would be sent as a change nobody could see, and a yaw crossing
## a 1.4° boundary changes its byte while `is_equal_approx` says it did not.
##
## It lives here, beside the writer, so the two cannot come apart. If they ever
## do, a record will be omitted as unchanged while its bytes differ, and the
## client will render a player at a position the server never had —
## `test_snapshot_delta.gd` asserts equal fingerprints serialise identically.
static func remote_fingerprint(record: Array) -> Array:
	var steps := Quantise.vector_to_i16(record[1] as Vector3)
	return [
		int(record[0]),
		steps[0],
		steps[1],
		steps[2],
		Quantise.yaw_to_u8(record[2]),
		state_index(record[3]),
		Quantise.pack(record[4], 6, record[5], 2),
	]


## The same idea for a crowd record, and it must match `_write_npcs` field for
## field or an NPC will be dropped as unchanged while its bytes differ.
##
## **THE HEIGHT IS A 5 CM BYTE AND THE POSITION A 1 CM `i16`**, which is why this
## cannot reuse `remote_fingerprint`: quantising an NPC's `y` at a centimetre
## would make a crowd member that drifts 2 cm vertically look changed on every
## tick, and the wire would carry a record identical to the one before it.
static func npc_fingerprint(record: Array) -> Array:
	var at := record[1] as Vector3
	return [
		int(record[0]),
		Quantise.pos_to_i16(at.x),
		Quantise.pos_to_i16(at.z),
		Quantise.height_to_u8(at.y),
		Quantise.yaw_to_u8(record[2]),
		Quantise.pack(record[3], 3, record[4], 5),
	]


static func serialise(snap: Snapshot) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	_write_header(snap, buffer)
	_write_own(snap, buffer)
	_write_compass_and_match(snap, buffer)
	_write_remotes(snap, buffer)
	_write_npcs(snap, buffer)
	return buffer.data_array


static func _write_header(snap: Snapshot, buffer: StreamPeerBuffer) -> void:
	buffer.put_u32(snap.server_tick)
	buffer.put_u16(snap.last_acked_seq)
	buffer.put_u8(snap.flags)
	buffer.put_u8(clampi(snap.baseline_age, Snapshot.FULL, Snapshot.MAX_BASELINE_AGE))


## The own-pawn block is **full floats, not quantised**. It is the authority the
## client reconciles its prediction against, and reconciling against a value
## rounded to a centimetre would put a permanent 1 cm disagreement into
## `TUN-NET-RECONCILE-THRESHOLD`'s 10 cm budget for nothing. It is sent once per
## snapshot, not five times, so the cost is 24 bytes against a budget measured in
## thousands.
static func _write_own(snap: Snapshot, buffer: StreamPeerBuffer) -> void:
	for value: float in [snap.own_position.x, snap.own_position.y, snap.own_position.z]:
		buffer.put_float(value)
	for value: float in [snap.own_velocity.x, snap.own_velocity.y, snap.own_velocity.z]:
		buffer.put_float(value)
	buffer.put_u8(state_index(snap.own_state))
	buffer.put_u16(snap.own_state_timer)
	buffer.put_u8(1 if snap.own_grounded else 0)

	buffer.put_u8(Quantise.suspicion_to_u8(snap.suspicion))
	buffer.put_u8(snap.active_sources)
	buffer.put_u16(snap.cooldown_a_tick)
	buffer.put_u16(snap.cooldown_b_tick)
	# tier u2, blend_state u4, kill_ready and stun_ready one bit each: eight bits,
	# one byte, and the packing is fixed by §4's widths.
	var flags_byte := Quantise.pack(snap.tier, 2, snap.blend_state, 4) << 2
	flags_byte |= (2 if snap.kill_ready else 0) | (1 if snap.stun_ready else 0)
	buffer.put_u8(flags_byte)
	# **THE ORDER IS `hunt` THEN `hunted`, AND A TRANSPOSITION HERE IS INVISIBLE.**
	# Two adjacent bytes of the same width holding two fractions of the same bar is
	# exactly the shape `ScoreAward` was extracted to avoid, and there is no type
	# that separates them. What catches it is the round trip and the builder both
	# being asserted with **two different values** — equal fixtures would agree
	# whichever way round they were written.
	buffer.put_u8(clampi(snap.hunt_fraction, 0, 255))
	buffer.put_u8(clampi(snap.hunted_fraction, 0, 255))


static func _write_compass_and_match(snap: Snapshot, buffer: StreamPeerBuffer) -> void:
	buffer.put_u8(snap.bearing)
	buffer.put_u8(snap.distance_bucket)
	buffer.put_u8(snap.lock_fraction)
	buffer.put_u8(1 if snap.portrait_revealed else 0)
	buffer.put_u8(snap.phase)
	buffer.put_u16(snap.ticks_remaining)
	buffer.put_u8(snap.multiplier)


static func _write_remotes(snap: Snapshot, buffer: StreamPeerBuffer) -> void:
	# **WHO EXISTS, THEN WHO MOVED.** The mask is written even on a full snapshot,
	# where it is derivable from the records. One byte buys a single decode path,
	# and a format whose shape depends on a flag is a format that gets read wrong
	# on the branch nobody tested.
	buffer.put_u8(snap.present_slots)
	buffer.put_u8(snap.remote_pawns.size())
	for record: Array in snap.remote_pawns:
		buffer.put_u8(record[0])
		for step: int in Quantise.vector_to_i16(record[1] as Vector3):
			buffer.put_16(step)
		buffer.put_u8(Quantise.yaw_to_u8(record[2]))
		buffer.put_u8(state_index(record[3]))
		buffer.put_u8(Quantise.pack(record[4], 6, record[5], 2))


## **THE CROWD IS WHERE THE BANDWIDTH IS**, so the crowd record is where it was
## found. Ninety NPCs against six players: a byte saved here is worth fifteen
## saved on a remote pawn.
##
## `x` and `z` keep their centimetre; `y` is a byte at 5 cm, because nothing
## reads a crowd member's height — the suspicion radius is horizontal, the
## compass is a bearing, and the strata are 3.5 m apart. The animation is `u3`
## state and `u5` phase in one byte: eight anim states is more than
## `CROWD_ANIM`'s five, and 32 phase steps is finer than a walk cycle can be read
## at the 45–70 m these records are sent from.
static func _write_npcs(snap: Snapshot, buffer: StreamPeerBuffer) -> void:
	buffer.put_u16(snap.npcs.size())
	for record: Array in snap.npcs:
		var position := record[1] as Vector3
		buffer.put_u8(record[0])
		buffer.put_16(Quantise.pos_to_i16(position.x))
		buffer.put_16(Quantise.pos_to_i16(position.z))
		buffer.put_u8(Quantise.height_to_u8(position.y))
		buffer.put_u8(Quantise.yaw_to_u8(record[2]))
		buffer.put_u8(Quantise.pack(record[3], 3, record[4], 5))


## The wire index of a state. `NO_STATE` for anything `PawnStateId` does not
## declare — a retired id decodes as "no state" rather than as whatever now sits
## at its old position.
static func state_index(state: StringName) -> int:
	var index := PawnStateId.ALL.find(state)
	return index if index >= 0 else Snapshot.NO_STATE


static func state_at(index: int) -> StringName:
	if index < 0 or index >= PawnStateId.ALL.size():
		return &""
	return PawnStateId.ALL[index]


## Read a snapshot back. Returns null on anything that is not one, rather than a
## half-filled object: a snapshot that decoded partially would move remote pawns
## to plausible wrong places, which is worse than a frame with no update.
static func deserialise(bytes: PackedByteArray) -> Snapshot:
	# The count fields too: `StreamPeerBuffer` returns zero on an over-read rather
	# than failing, so a buffer one byte short of the NPC count would decode as a
	# snapshot with no NPCs in it — silently, and every frame.
	if bytes.size() < Snapshot.HEADER_BYTES + Snapshot.OWN_BYTES + Snapshot.COUNT_BYTES:
		return null
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.data_array = bytes
	var snap := Snapshot.new()
	snap.server_tick = buffer.get_u32()
	snap.last_acked_seq = buffer.get_u16()
	snap.flags = buffer.get_u8()
	snap.baseline_age = buffer.get_u8()
	_read_own(snap, buffer)
	_read_compass_and_match(snap, buffer)
	if not _read_remotes(snap, buffer) or not _read_npcs(snap, buffer):
		return null
	return snap


static func _read_own(snap: Snapshot, buffer: StreamPeerBuffer) -> void:
	snap.own_position = Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
	snap.own_velocity = Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
	snap.own_state = state_at(buffer.get_u8())
	snap.own_state_timer = buffer.get_u16()
	snap.own_grounded = buffer.get_u8() != 0

	snap.suspicion = float(buffer.get_u8())
	snap.active_sources = buffer.get_u8()
	snap.cooldown_a_tick = buffer.get_u16()
	snap.cooldown_b_tick = buffer.get_u16()
	var flags_byte := buffer.get_u8()
	snap.kill_ready = (flags_byte & 2) != 0
	snap.stun_ready = (flags_byte & 1) != 0
	var packed := flags_byte >> 2
	snap.tier = Quantise.unpack_high(packed, 4, 2)
	snap.blend_state = Quantise.unpack_low(packed, 4)
	snap.hunt_fraction = buffer.get_u8()
	snap.hunted_fraction = buffer.get_u8()


static func _read_compass_and_match(snap: Snapshot, buffer: StreamPeerBuffer) -> void:
	snap.bearing = buffer.get_u8()
	snap.distance_bucket = buffer.get_u8()
	snap.lock_fraction = buffer.get_u8()
	snap.portrait_revealed = buffer.get_u8() != 0
	snap.phase = buffer.get_u8()
	snap.ticks_remaining = buffer.get_u16()
	snap.multiplier = buffer.get_u8()


static func _read_remotes(snap: Snapshot, buffer: StreamPeerBuffer) -> bool:
	snap.present_slots = buffer.get_u8()
	var count := buffer.get_u8()
	if buffer.get_available_bytes() < count * Snapshot.REMOTE_BYTES:
		return false
	for _i: int in count:
		var slot := buffer.get_u8()
		var position := Quantise.i16_to_vector(buffer.get_16(), buffer.get_16(), buffer.get_16())
		var yaw := Quantise.u8_to_yaw(buffer.get_u8())
		var state := state_at(buffer.get_u8())
		var packed := buffer.get_u8()
		snap.add_remote(
			slot,
			position,
			yaw,
			state,
			Quantise.unpack_high(packed, 2, 6),
			Quantise.unpack_low(packed, 2)
		)
	return true


static func _read_npcs(snap: Snapshot, buffer: StreamPeerBuffer) -> bool:
	var count := buffer.get_u16()
	if buffer.get_available_bytes() < count * Snapshot.NPC_BYTES:
		return false
	for _i: int in count:
		var index := buffer.get_u8()
		var x := Quantise.i16_to_pos(buffer.get_16())
		var z := Quantise.i16_to_pos(buffer.get_16())
		var y := Quantise.u8_to_height(buffer.get_u8())
		var yaw := Quantise.u8_to_yaw(buffer.get_u8())
		var packed := buffer.get_u8()
		snap.add_npc(
			index,
			Vector3(x, y, z),
			yaw,
			Quantise.unpack_high(packed, 5, 3),
			Quantise.unpack_low(packed, 5)
		)
	return true
