## **`NET-S2C-LOBBY-STATE`, PACKED: WHO IS IN THIS MATCH AND WHAT THEY WEAR.**
## NETWORK_PROTOCOL §3, US-0101. PURE.
##
## `count:u8`, then `count` × (`slot:u8`, `persona:u8`). The persona byte is
## `PersonaWire`'s, so `NONE` 255 is a real reading — a player the countdown has
## not dealt to yet — and a client draws them undressed rather than guessing.
##
## **THE ROW HAS SAID `players[]{peer_id, persona, ready}` SINCE M0, AND `ready`
## IS NOT HERE.** Nothing readies up until US-0078's lobby, so a `ready` byte today
## would be a field the server writes as a constant and nobody reads — the shape
## this corpus has paid for eight times. The lobby appends it with its own
## `PROTOCOL_VERSION` bump, when it has a writer.
##
## **WHY EVERY PLAYER'S PERSONA IS SENT TO EVERY PLAYER.** A body in the district is
## drawn in its persona's colour and silhouette, so what a client is told here it
## would see anyway the moment the figure is in view. What it may not learn is
## *which figure is a player*, and that is never on this message: a slot names a
## snapshot record, and the snapshot has always said which records are players.
class_name LobbyStateWire
extends RefCounted

## A payload that cannot be a roster. Never a legal count: six seats fit in a byte.
const MALFORMED := -1


## `by_slot` is `{slot: persona}`. Slots outside a byte are dropped rather than
## wrapped, because a wrapped slot names the wrong player.
static func pack(by_slot: Dictionary) -> PackedByteArray:
	var slots: Array = by_slot.keys().filter(func(s: int) -> bool: return s > 0 and s < 256)
	slots.sort()
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(slots.size())
	for slot: int in slots:
		buffer.put_u8(slot)
		buffer.put_u8(PersonaWire.to_u8(by_slot[slot]))
	return buffer.data_array


## `[{slot: persona}]`, or `[]` for a payload whose length disagrees with its own
## count. **A short packet is dropped whole**, `MatchStartWire`'s rule: a read past
## the end answers zero, and slot 0 persona 0 is a plausible Cantatrice for nobody.
static func unpack(bytes: PackedByteArray) -> Array:
	if bytes.is_empty() or bytes.size() != 1 + 2 * bytes[0]:
		return []
	var by_slot: Dictionary = {}
	for i: int in bytes[0]:
		by_slot[int(bytes[1 + 2 * i])] = PersonaWire.from_u8(bytes[2 + 2 * i])
	return [by_slot]
