## **`NET-C2S-INPUT` ON THE WIRE.** NETWORK_PROTOCOL §2, TDD-04 §6.1, US-0095.
##
## PURE. Twelve bytes in, an `InputCommand` out, with no peer and no world — so
## every field of the layout is a round-trip test.
##
## **WHY THIS EXISTS AT ALL.** Until now the command went out as six loose RPC
## arguments, and Godot encodes those as Variants: an `int` costs 8 bytes, a
## `Vector2` 12, a `float` 8 or 12. **Fifty-six bytes** for what §6.1 budgets at
## nine, which put upstream at **253 % of `TUN-NET-BUDGET-UP`** — measured at the
## M2 gate, US-0038.
##
## **QUANTISE AT SAMPLE TIME, NOT AT SEND TIME.** This is the whole correctness
## story. The client predicts with the command it holds and the server simulates
## with the command it received; if those differ by even one rounding step, the
## two diverge on **every frame** and the reconciler papers over it forever.
## `InputSampler` therefore writes *already-quantised* values into the command
## through the `quantise_*` helpers below, so `serialise` → `deserialise` is
## **exactly lossless** from that point on. `test_input_codec.gd` asserts it.
##
## **THE LAYOUT IS NOT §6.1'S, AND THE REASON IS PADDING.** §6.1 declares
## `yaw:u8` and `pitch:i8`. Measured, a `PackedByteArray` RPC argument costs
## **8 bytes of Variant wrapper plus the payload rounded up to 4** — so a 10-byte
## payload and a 12-byte payload **both cost 20 bytes on the wire**. The two bytes
## §6.1's narrower fields would save are free, and they are not free of cost
## elsewhere:
##
## - **`pitch:i8` would stair-step the camera.** `camera_rig.gd` reads
##   `command.look_pitch` directly to place the arm; 180° in 256 steps is 0.7° per
##   step, visible on any slow mouse drag.
## - **`yaw:u8` would make a slow drag stick.** The sampler accumulates look; at
##   1.4° per step, a frame that moves less than 0.7° rounds back to where it
##   started and the camera does not turn at all.
##
## `u16` yaw and `i16` pitch are **0.0055°** — finer than a mouse can express,
## free on the wire, and immune to both.
class_name InputCodec
extends RefCounted

## Payload bytes. **Not the wire cost** — see `wire_bytes()`.
const BYTES := 12

const YAW_STEPS := 65536.0
const PITCH_STEPS := 65536.0
const MOVE_SCALE := 127.0


## What one command actually costs as an RPC argument: the payload rounded up to
## a multiple of four, plus Godot's 8-byte Variant header for a `PackedByteArray`.
##
## Measured, not assumed — the M2 gate found §7.3 budgeting a payload that
## nothing ever put on the wire, and this is the arithmetic that stops that
## recurring.
static func wire_bytes(payload: int = BYTES) -> int:
	return 8 + int(ceil(float(payload) / 4.0)) * 4


## Yaw rounded to what the wire can carry. **Radians in, radians out** — the
## caller stores the result, so client and server hold the same number.
static func quantise_yaw(radians: float) -> float:
	return _from_yaw(_to_yaw(radians))


static func quantise_pitch(radians: float) -> float:
	return _from_pitch(_to_pitch(radians))


static func quantise_move(v: Vector2) -> Vector2:
	return Vector2(_from_axis(_to_axis(v.x)), _from_axis(_to_axis(v.y)))


static func _to_yaw(radians: float) -> int:
	var turns := wrapf(radians, -PI, PI) / TAU + 0.5
	return clampi(int(round(turns * (YAW_STEPS - 1.0))), 0, 65535)


static func _from_yaw(raw: int) -> float:
	return wrapf((float(raw) / (YAW_STEPS - 1.0) - 0.5) * TAU, -PI, PI)


## Pitch is clamped to ±90° by the sampler, so the range is half a turn.
static func _to_pitch(radians: float) -> int:
	var t := clampf(radians, -PI / 2.0, PI / 2.0) / PI + 0.5
	return clampi(int(round(t * (PITCH_STEPS - 1.0))), 0, 65535)


static func _from_pitch(raw: int) -> float:
	return (float(raw) / (PITCH_STEPS - 1.0) - 0.5) * PI


static func _to_axis(value: float) -> int:
	return clampi(int(round(clampf(value, -1.0, 1.0) * MOVE_SCALE)), -127, 127)


static func _from_axis(raw: int) -> float:
	return float(raw) / MOVE_SCALE


static func serialise(command: InputCommand) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u16(command.seq & 0xFFFF)
	buffer.put_8(_to_axis(command.move.x))
	buffer.put_8(_to_axis(command.move.y))
	buffer.put_u16(_to_yaw(command.look_yaw))
	buffer.put_u16(_to_pitch(command.look_pitch))
	buffer.put_u16(command.buttons & 0xFFFF)
	buffer.put_u16(command.acked_tick & 0xFFFF)
	return buffer.data_array


## `null` on a buffer that is not the right size. **Refused, never partially
## decoded**: `StreamPeerBuffer` returns zero on an over-read rather than
## failing, so a short buffer would silently decode as a command holding no
## buttons and no movement — which the server would then simulate.
static func deserialise(bytes: PackedByteArray) -> InputCommand:
	if bytes.size() != BYTES:
		return null
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.data_array = bytes
	var command := InputCommand.new()
	command.seq = buffer.get_u16()
	command.move = Vector2(_from_axis(buffer.get_8()), _from_axis(buffer.get_8()))
	command.look_yaw = _from_yaw(buffer.get_u16())
	command.look_pitch = _from_pitch(buffer.get_u16())
	command.buttons = buffer.get_u16()
	command.acked_tick = buffer.get_u16()
	return command
