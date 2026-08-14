## **THE WIRE FORMAT.** NETWORK_PROTOCOL §4, US-0029.
##
## PURE. A value object plus its serialiser, so every field of the layout is a
## round-trip test with no peer and no world.
##
## **THE INFORMATION RULES LIVE HERE, NOT IN THE UI.** GDD-03 forbids a hunter
## ever learning their contract's persona, exact position, elevation or tier —
## and a rule that lives in a widget can be broken by a different widget, while a
## rule that lives in the wire format cannot be broken at all. The compass block
## carries a *bucket* and a *bearing with the wobble already applied*, because
## the client is never given a number precise enough to undo.
##
## **NO PEER IDS.** A remote pawn is identified by its `SlotTable` slot, which is
## a byte, which is what the bandwidth budget was written against — see
## `slot_table.gd` for why the engine's 32-bit ids never reach the wire.
##
## **THE FIELD ORDER IS THE WIRE.** Reordering is not a refactor: a peer running
## a different build during a rolling restart reads positionally, and every
## misread value is a plausible one.
class_name Snapshot
extends RefCounted

## `state_id` on the wire is an index into `PawnStateId.ALL`. **THAT ARRAY'S
## ORDER IS THEREFORE PART OF THE PROTOCOL** — appending is safe, reordering
## silently remaps every remote pawn's animation to a different state.
const NO_STATE := 255

## **THE MEASURED RECORD SIZES**, from the fields §4 declares. They are constants
## here because the bandwidth arithmetic depends on them and because §7.1's table
## quotes different numbers — see US-0029.
const HEADER_BYTES := 7
const OWN_BYTES := 43
const REMOTE_BYTES := 10
const NPC_BYTES := 10

## The two length fields: one byte of remote pawns, two of NPCs.
const COUNT_BYTES := 3

# --- header ---
var server_tick: int = 0
var last_acked_seq: int = 0
var flags: int = 0

# --- own pawn: FULL, because this is what prediction is reconciled against ---
var own_position: Vector3 = Vector3.ZERO
var own_velocity: Vector3 = Vector3.ZERO
var own_state: StringName = PawnStateId.IDLE
var own_state_timer: int = 0
var own_grounded: bool = false

# --- own gameplay: NEVER predicted (ADR-0002) ---
var suspicion: float = 0.0
var tier: int = 0
var active_sources: int = 0
var cooldown_a_tick: int = 0
var cooldown_b_tick: int = 0
var blend_state: int = 0
var kill_ready: bool = false
var stun_ready: bool = false

# --- compass: bucketed and wobbled server-side ---
var bearing: int = 0
var distance_bucket: int = 0
var lock_fraction: int = 0
var portrait_revealed: bool = false

# --- match ---
var phase: int = 0
var ticks_remaining: int = 0
var multiplier: int = 1

## `[slot, position, yaw, state, anim_phase, render_state]` per visible player.
var remote_pawns: Array = []

## `[index, position, yaw, anim_state, anim_phase]` per replicated NPC.
var npcs: Array = []


## Add a remote pawn record. Takes a **slot**, never a peer id — the signature is
## where that rule is easiest to keep.
func add_remote(
	slot: int, position: Vector3, yaw: float, state: StringName, phase_bits: int, render: int
) -> void:
	remote_pawns.append([slot, position, yaw, state, phase_bits, render])


func add_npc(index: int, position: Vector3, yaw: float, anim_state: int, phase_bits: int) -> void:
	npcs.append([index, position, yaw, anim_state, phase_bits])


func serialise() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	_write_header(buffer)
	_write_own(buffer)
	_write_compass_and_match(buffer)
	_write_remotes(buffer)
	_write_npcs(buffer)
	return buffer.data_array


func _write_header(buffer: StreamPeerBuffer) -> void:
	buffer.put_u32(server_tick)
	buffer.put_u16(last_acked_seq)
	buffer.put_u8(flags)


## The own-pawn block is **full floats, not quantised**. It is the authority the
## client reconciles its prediction against, and reconciling against a value
## rounded to a centimetre would put a permanent 1 cm disagreement into
## `TUN-NET-RECONCILE-THRESHOLD`'s 10 cm budget for nothing. It is sent once per
## snapshot, not five times, so the cost is 24 bytes against a budget measured in
## thousands.
func _write_own(buffer: StreamPeerBuffer) -> void:
	for value: float in [own_position.x, own_position.y, own_position.z]:
		buffer.put_float(value)
	for value: float in [own_velocity.x, own_velocity.y, own_velocity.z]:
		buffer.put_float(value)
	buffer.put_u8(state_index(own_state))
	buffer.put_u16(own_state_timer)
	buffer.put_u8(1 if own_grounded else 0)

	buffer.put_u8(Quantise.suspicion_to_u8(suspicion))
	buffer.put_u8(active_sources)
	buffer.put_u16(cooldown_a_tick)
	buffer.put_u16(cooldown_b_tick)
	# tier u2, blend_state u4, kill_ready and stun_ready one bit each: eight bits,
	# one byte, and the packing is fixed by §4's widths.
	var flags_byte := Quantise.pack(tier, 2, blend_state, 4) << 2
	flags_byte |= (2 if kill_ready else 0) | (1 if stun_ready else 0)
	buffer.put_u8(flags_byte)


func _write_compass_and_match(buffer: StreamPeerBuffer) -> void:
	buffer.put_u8(bearing)
	buffer.put_u8(distance_bucket)
	buffer.put_u8(lock_fraction)
	buffer.put_u8(1 if portrait_revealed else 0)
	buffer.put_u8(phase)
	buffer.put_u16(ticks_remaining)
	buffer.put_u8(multiplier)


func _write_remotes(buffer: StreamPeerBuffer) -> void:
	buffer.put_u8(remote_pawns.size())
	for record: Array in remote_pawns:
		buffer.put_u8(record[0])
		for step: int in Quantise.vector_to_i16(record[1] as Vector3):
			buffer.put_16(step)
		buffer.put_u8(Quantise.yaw_to_u8(record[2]))
		buffer.put_u8(state_index(record[3]))
		buffer.put_u8(Quantise.pack(record[4], 6, record[5], 2))


func _write_npcs(buffer: StreamPeerBuffer) -> void:
	buffer.put_u16(npcs.size())
	for record: Array in npcs:
		buffer.put_u8(record[0])
		for step: int in Quantise.vector_to_i16(record[1] as Vector3):
			buffer.put_16(step)
		buffer.put_u8(Quantise.yaw_to_u8(record[2]))
		# anim_state u4 + phase u6 is ten bits, so it costs two. §4 writes it as
		# "u4 + phase u6 == 7 bytes per NPC including index", and those two halves
		# of the sentence disagree — see US-0029 on the record sizes.
		buffer.put_u16(Quantise.pack(record[3], 4, record[4], 6))


## The wire index of a state. `NO_STATE` for anything `PawnStateId` does not
## declare — a retired id decodes as "no state" rather than as whatever now sits
## at its old position.
static func state_index(state: StringName) -> int:
	var index := PawnStateId.ALL.find(state)
	return index if index >= 0 else NO_STATE


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
	if bytes.size() < HEADER_BYTES + OWN_BYTES + COUNT_BYTES:
		return null
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.data_array = bytes
	var snap := Snapshot.new()
	snap.server_tick = buffer.get_u32()
	snap.last_acked_seq = buffer.get_u16()
	snap.flags = buffer.get_u8()
	snap._read_own(buffer)
	snap._read_compass_and_match(buffer)
	if not snap._read_remotes(buffer) or not snap._read_npcs(buffer):
		return null
	return snap


func _read_own(buffer: StreamPeerBuffer) -> void:
	own_position = Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
	own_velocity = Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
	own_state = state_at(buffer.get_u8())
	own_state_timer = buffer.get_u16()
	own_grounded = buffer.get_u8() != 0

	suspicion = float(buffer.get_u8())
	active_sources = buffer.get_u8()
	cooldown_a_tick = buffer.get_u16()
	cooldown_b_tick = buffer.get_u16()
	var flags_byte := buffer.get_u8()
	kill_ready = (flags_byte & 2) != 0
	stun_ready = (flags_byte & 1) != 0
	var packed := flags_byte >> 2
	tier = Quantise.unpack_high(packed, 4, 2)
	blend_state = Quantise.unpack_low(packed, 4)


func _read_compass_and_match(buffer: StreamPeerBuffer) -> void:
	bearing = buffer.get_u8()
	distance_bucket = buffer.get_u8()
	lock_fraction = buffer.get_u8()
	portrait_revealed = buffer.get_u8() != 0
	phase = buffer.get_u8()
	ticks_remaining = buffer.get_u16()
	multiplier = buffer.get_u8()


func _read_remotes(buffer: StreamPeerBuffer) -> bool:
	var count := buffer.get_u8()
	if buffer.get_available_bytes() < count * REMOTE_BYTES:
		return false
	for _i: int in count:
		var slot := buffer.get_u8()
		var position := Quantise.i16_to_vector(buffer.get_16(), buffer.get_16(), buffer.get_16())
		var yaw := Quantise.u8_to_yaw(buffer.get_u8())
		var state := state_at(buffer.get_u8())
		var packed := buffer.get_u8()
		add_remote(
			slot,
			position,
			yaw,
			state,
			Quantise.unpack_high(packed, 2, 6),
			Quantise.unpack_low(packed, 2)
		)
	return true


func _read_npcs(buffer: StreamPeerBuffer) -> bool:
	var count := buffer.get_u16()
	if buffer.get_available_bytes() < count * NPC_BYTES:
		return false
	for _i: int in count:
		var index := buffer.get_u8()
		var position := Quantise.i16_to_vector(buffer.get_16(), buffer.get_16(), buffer.get_16())
		var yaw := Quantise.u8_to_yaw(buffer.get_u8())
		var packed := buffer.get_u16()
		add_npc(
			index, position, yaw, Quantise.unpack_high(packed, 6, 4), Quantise.unpack_low(packed, 6)
		)
	return true
