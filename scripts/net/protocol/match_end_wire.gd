## **`NET-S2C-MATCH-END`, PACKED.** `NETWORK_PROTOCOL.md` §2, US-0077.
##
## The one message in this game that withholds nothing. Every other server-to-client
## message is built around never-do #12 — a kill result reaches two players, a score
## event reaches its actor alone, and the snapshot carries no other player's
## suspicion at all — because a global feed converts an earned inference into a given
## fact. **At the end of a match that restriction lifts by design**: US-0077 is the
## teaching moment and asks in as many words for every player's breakdown, their
## kit, and who killed you. There is nothing left to infer.
##
## **THE FULL EVENT LOG TRAVELS, NOT A SUMMARY**, which is US-0077's third criterion
## made structural: the placement and the per-bonus breakdown both come out of
## `ScoreFold` over this one array, so there is no second arithmetic for them to
## disagree across. The catalogue budgets it at ~24 KB, which is 1 600 rows at the
## fifteen bytes below — a full six-player match is a few hundred.
##
## **AND IT IS HAND-PACKED FOR THE REASON `ScoreWire`'s DOCSTRING GIVES.** Godot
## variant-encodes a loose RPC argument, and this payload is the largest single
## message the protocol has; a `u32` sent as a Variant is eight bytes rather than
## four, which on a log this size is not a rounding detail.
class_name MatchEndWire
extends RefCounted

## `event_id:u32, tick:u32, kind:u8, actor:u8, subject:u8, base:i16, group:u16`.
const ROW := 15

## What a header costs before the first player row: the player count alone.
const HEADER := 1

## `slot:u8, anonymous_ticks:u32, kit_len:u8` before the kit bytes themselves.
const PLAYER_HEADER := 6

## Beyond this the log is truncated rather than sent, because `event_count` is a
## `u16` and a silently wrapped count decodes as a different match.
const MAX_EVENTS := 65535


## Every player's kit and patience, and the whole log, addressed by wire slot.
##
## **`slot_of` IS PASSED IN RATHER THAN LOOKED UP**, so this stays Core-shaped and a
## test can pack a log with no `SlotTable` and no server standing up.
static func pack(
	anonymous: Dictionary, kits: Dictionary, events: Array[ScoreEvent], slot_of: Callable
) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	var slots: Array = anonymous.keys()
	buffer.put_u8(mini(slots.size(), 255))
	for slot: int in slots:
		buffer.put_u8(slot)
		buffer.put_u32(maxi(int(anonymous[slot]), 0))
		var kit: Array = kits.get(slot, [])
		buffer.put_u8(kit.size())
		for id: StringName in kit:
			buffer.put_u8(AbilityKinds.to_byte(id))
	var sent: Array[ScoreEvent] = []
	for event: ScoreEvent in events:
		if sent.size() >= MAX_EVENTS:
			break
		sent.append(event)
	buffer.put_u16(sent.size())
	for event: ScoreEvent in sent:
		_put_event(buffer, event, slot_of)
	return buffer.data_array


static func _put_event(buffer: StreamPeerBuffer, event: ScoreEvent, slot_of: Callable) -> void:
	buffer.put_u32(event.event_id)
	buffer.put_u32(maxi(event.tick, 0))
	buffer.put_u8(ScoreKinds.to_byte(event.kind))
	buffer.put_u8(int(slot_of.call(event.actor_id)))
	buffer.put_u8(int(slot_of.call(event.subject_id)))
	buffer.put_16(clampi(event.base_points, -32768, 32767))
	buffer.put_u16(event.group_id)


## **A SHORT OR OVERLONG PACKET IS DROPPED WHOLE, NEVER PARTLY READ**, which is
## `ScoreWire`'s rule and it matters more here: `StreamPeerBuffer` answers a read
## past the end with zero, so an unchecked decode would build a results screen out of
## slot 0 scoring nothing — a scoreboard the server never sent, shown at the one
## moment players are reading the game's own account of what they did.
static func unpack(bytes: PackedByteArray, rules: MatchTuning) -> MatchEndReport:
	if bytes.size() < HEADER:
		return null
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	var report := MatchEndReport.new()
	var players := buffer.get_u8()
	for _i: int in players:
		if not _read_player(buffer, report, bytes.size()):
			return null
	if buffer.get_position() + 2 > bytes.size():
		return null
	var count := buffer.get_u16()
	if buffer.get_position() + count * ROW != bytes.size():
		return null
	for _i: int in count:
		report.events.append(_read_event(buffer, rules))
	return report


static func _read_player(buffer: StreamPeerBuffer, report: MatchEndReport, size: int) -> bool:
	if buffer.get_position() + PLAYER_HEADER > size:
		return false
	var slot := buffer.get_u8()
	report.anonymous_ticks[slot] = buffer.get_u32()
	var kit_len := buffer.get_u8()
	if buffer.get_position() + kit_len > size:
		return false
	var kit: Array[StringName] = []
	for _k: int in kit_len:
		kit.append(AbilityKinds.from_byte(buffer.get_u8()))
	report.kits[slot] = kit
	return true


## **THE EVENT IS REBUILT THROUGH ITS OWN CONSTRUCTOR**, so the client cannot hold a
## `ScoreEvent` the server could not have built. That constructor derives the
## multiplier from the tick against `rules`, which is why the multiplier is not on
## the wire: two fields that are already here imply it, and the handshake guarantees
## both peers hold the same `MatchTuning`.
static func _read_event(buffer: StreamPeerBuffer, rules: MatchTuning) -> ScoreEvent:
	var id := buffer.get_u32()
	var tick := buffer.get_u32()
	var kind := ScoreKinds.from_byte(buffer.get_u8())
	var actor := buffer.get_u8()
	var subject := buffer.get_u8()
	var base := buffer.get_16()
	var group := buffer.get_u16()
	return ScoreEvent.new(id, ScoreAward.new(tick, kind, actor, subject, float(base)), rules, group)
