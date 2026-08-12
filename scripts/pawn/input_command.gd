## One sampled frame of player intent. TDD-03 §5, TDD-06 §3.
##
## **THE LAYOUT IS FIXED**, because it is the wire format of `NET-C2S-INPUT`
## (NETWORK_PROTOCOL §2): `seq:u16`, `move:2×i8`, `yaw:u8`, `pitch:i8`,
## `buttons:u16`, `client_tick:u16`. Sent at `TUN-NET-CLIENT-INPUT-RATE` 60 Hz.
##
## THE CLIENT SENDS INTENT, NEVER OUTCOME. There is no "I killed X" here and
## there never will be: kill and stun are *buttons*, validated server-side
## against the lag-compensated world (CLAUDE.md never-do #2).
##
## The ten booleans below are views onto `buttons`, not storage. `buttons` is the
## single field, so a command cannot be in a state where the bitfield and the
## flag disagree — which is the failure that would make a prediction replay
## diverge from the server for reasons no log would show.
class_name InputCommand
extends RefCounted

## Monotonic per client, never reused within a match. Used for ack and
## reconciliation, and it is what orders a client's own inputs — not time.
var seq: int = 0

## Desired movement, length <= 1. Quantised to 8 bits per axis on the wire.
##
## **IN THE CAMERA'S FRAME, NOT THE WORLD'S.** `+y` is forward and `+x` is right
## *as the player sees it*; the world direction is this rotated onto `look_yaw`,
## which `LocomotionState._world_direction` does and nothing else may. Read as a
## world vector — which is how it shipped from US-0015 — W walks north whatever
## the camera is doing, and A walks west, which at yaw 0 is the pawn's right.
var move: Vector2 = Vector2.ZERO

## Facing, radians. Quantised to `TUN-NET-QUANT-YAW` on the wire.
var look_yaw: float = 0.0

## Pitch, radians. Camera-only today; it reaches the pawn because aim will need
## it and a layout change later is a protocol break.
var look_pitch: float = 0.0

## Every button, as `InputBits`. Held state, not events — the server receives
## this at 30 Hz having missed frames, so edges are derived (`InputBits.
## newly_pressed`), never transmitted.
var buttons: int = InputBits.NONE

## The client's tick when this was sampled.
##
## **ADVISORY ONLY.** Used for diagnostics and nothing else. It is NEVER used to
## order events or resolve contests: it is client-supplied and therefore
## forgeable, and a contest resolved on a forgeable number is a contest the
## attacker wins. Contest resolution uses the server receive tick (ADR-0010).
var client_tick: int = 0

# --- Views onto `buttons`. No storage of their own. ---

var slow: bool:
	get:
		return InputBits.is_set(buttons, InputBits.SLOW)
	set(value):
		buttons = InputBits.with(buttons, InputBits.SLOW, value)

var run: bool:
	get:
		return InputBits.is_set(buttons, InputBits.RUN)
	set(value):
		buttons = InputBits.with(buttons, InputBits.RUN, value)

## `INPUT-RUN` at full pull. Only this escalates Jog -> Run; a half-pulled
## trigger holds the pad at jog, which is GDD-02 §1.3's analogue advantage.
var run_full: bool:
	get:
		return InputBits.is_set(buttons, InputBits.RUN_FULL)
	set(value):
		buttons = InputBits.with(buttons, InputBits.RUN_FULL, value)

var sprint: bool:
	get:
		return InputBits.is_set(buttons, InputBits.SPRINT)
	set(value):
		buttons = InputBits.with(buttons, InputBits.SPRINT, value)

var traverse: bool:
	get:
		return InputBits.is_set(buttons, InputBits.TRAVERSE)
	set(value):
		buttons = InputBits.with(buttons, InputBits.TRAVERSE, value)

var kill: bool:
	get:
		return InputBits.is_set(buttons, InputBits.KILL)
	set(value):
		buttons = InputBits.with(buttons, InputBits.KILL, value)

var stun: bool:
	get:
		return InputBits.is_set(buttons, InputBits.STUN)
	set(value):
		buttons = InputBits.with(buttons, InputBits.STUN, value)

var blend: bool:
	get:
		return InputBits.is_set(buttons, InputBits.BLEND)
	set(value):
		buttons = InputBits.with(buttons, InputBits.BLEND, value)

var ability_1: bool:
	get:
		return InputBits.is_set(buttons, InputBits.ABILITY_1)
	set(value):
		buttons = InputBits.with(buttons, InputBits.ABILITY_1, value)

var ability_2: bool:
	get:
		return InputBits.is_set(buttons, InputBits.ABILITY_2)
	set(value):
		buttons = InputBits.with(buttons, InputBits.ABILITY_2, value)

var scan: bool:
	get:
		return InputBits.is_set(buttons, InputBits.SCAN)
	set(value):
		buttons = InputBits.with(buttons, InputBits.SCAN, value)


func wants_movement() -> bool:
	return move.length_squared() > 0.0


## A fresh command for `for_seq`, so tests do not have to remember which fields
## default to what.
static func empty(for_seq: int = 0) -> InputCommand:
	var command := InputCommand.new()
	command.seq = for_seq
	return command


## An independent copy. The reconciliation ring keeps commands after they have
## been sent, and a sampler that reused one object would rewrite its own history.
func duplicate_command() -> InputCommand:
	var out := InputCommand.new()
	out.seq = seq
	out.move = move
	out.look_yaw = look_yaw
	out.look_pitch = look_pitch
	out.buttons = buttons
	out.client_tick = client_tick
	return out
