## **`NET-S2C-SCORE-EVENT`, PACKED THE WAY THE CATALOGUE DECLARES IT.**
## `NETWORK_PROTOCOL.md` §4, TDD-04 §4, US-0074.
##
## The row is `event_id:u32, tick:u32, kind:u8, actor:u8, subject:u8, base:i16,
## mult:u8, group:u16` — **sixteen bytes**, and this is the one place that layout
## is written down as code.
##
## **IT IS HAND-PACKED RATHER THAN SENT AS EIGHT RPC ARGUMENTS, WHICH IS US-0095's
## LESSON APPLIED BEFORE IT COST ANYTHING.** Godot encodes a loose RPC argument as
## a Variant — `NET-C2S-INPUT` went out at **56 bytes against a budgeted 9** that
## way, and nothing said so until somebody measured it. Sixteen bytes of payload
## against eight Variants is the same defect at a twentieth of the frequency, and
## the frequency is not the reason to fix it.
##
## **THE REAL REASON IS THAT THE DECLARED WIDTHS BECOME REAL.** `base:i16` sent as
## a Variant int accepts 40 000 silently; sent through `put_16` it does not. And
## `gdlint` refused the eight-argument signature outright, which `.gdlintrc` says
## is *"a design signal, not a style preference"* — it was right: eight positional
## integers in which transposing `actor` and `subject` is invisible is exactly the
## shape `ScoreAward` was extracted to avoid in US-0064.
class_name ScoreWire
extends RefCounted

## What `pack` always produces and `unpack` requires. Asserted rather than
## commented, because a row that silently grew a field would decode as garbage
## from the field after it.
const SIZE := 16

## `multiplier` is `1.0` or `TUN-MATCH-FINALPHASE-MULT`, whose own
## `@export_range` is 1.5–3.0. **Tenths, so the byte spans 0.0–25.5** — three
## times the widest value the tuning can hold, with no clamping to reason about.
const MULT_STEP := 0.1


static func pack(event: ScoreEvent, actor_slot: int, subject_slot: int) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u32(event.event_id)
	buffer.put_u32(event.tick)
	buffer.put_u8(ScoreKinds.to_byte(event.kind))
	buffer.put_u8(actor_slot)
	buffer.put_u8(subject_slot)
	buffer.put_16(clampi(event.base_points, -32768, 32767))
	buffer.put_u8(multiplier_to_u8(event.multiplier))
	buffer.put_u16(event.group_id)
	return buffer.data_array


## **A SHORT PACKET IS DROPPED, NOT PARTLY READ.** `StreamPeerBuffer` answers a
## read past the end with zero, so an unpack that did not check its length would
## turn a truncated packet into `SCORE-CONTRACT` for 0 points — a feed line the
## server never sent, which is the one thing a score feed must never draw.
static func unpack(bytes: PackedByteArray) -> ScoreReport:
	if bytes.size() != SIZE:
		return null
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.get_u32()  # event_id — the fold's key, and a feed folds nothing
	buffer.get_u32()  # tick — judged-at, where the feed draws at arrived-at
	var kind := ScoreKinds.from_byte(buffer.get_u8())
	buffer.get_u8()  # actor — always this client, because the actor is the recipient
	buffer.get_u8()  # subject — somebody this client has already earned. See §5
	var base := buffer.get_16()
	var multiplier := u8_to_multiplier(buffer.get_u8())
	return ScoreReport.new(kind, ScoreEvent.points_of(base, multiplier), buffer.get_u16())


static func multiplier_to_u8(multiplier: float) -> int:
	return clampi(int(round(multiplier / MULT_STEP)), 0, 255)


static func u8_to_multiplier(value: int) -> float:
	return float(value) * MULT_STEP
