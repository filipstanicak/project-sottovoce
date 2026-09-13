## **`NET-S2C-MATCH-START`, PACKED.** `NETWORK_PROTOCOL.md` §2, US-0079.
##
## Three numbers, and the first of them is the one this message exists for: the
## **match seed**. Everything derived rather than replicated comes from it —
## `CrowdRoster` gives every NPC its persona from `hash(match_seed)`, identically on
## every peer, which is what lets ninety identities cost nothing on the wire.
##
## **SO THE SEED MUST ARRIVE BIT-EXACT, AND THAT IS NOT A PEDANTIC CLAIM.** One bit
## different and every NPC on that client wears a different persona from the one the
## server placed — and the clone-parity floor, the thing the whole social-stealth
## mechanic rests on, would be satisfied on the server and false on the screen. It
## would look like correct behaviour. `test_match_start_wire.gd` sweeps the values
## that break a careless encoder: zero, the `--seed` a playtest was launched with, and
## a seed with its top bit set.
##
## **`crowd_count:u8` IS WHY THIS IS PACKED RATHER THAN SENT AS THREE ARGUMENTS.**
## Godot Variant-encodes a loose RPC argument, so a declared `u8` accepts 500 in
## silence — and `ScoreWire`'s docstring already names that as the real reason to
## hand-pack, above the bytes: **the declared widths become real.** `TUN-CROWD-COUNT-MAX`
## is 90, so the byte is honest and a count that outgrew it would be a loud change
## rather than a quiet truncation.
class_name MatchStartWire
extends RefCounted

## `match_seed:u64, start_tick:u32, crowd_count:u8`.
const SIZE := 13


static func pack(match_seed: int, start_tick: int, crowd_count: int) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u64(match_seed)
	buffer.put_u32(maxi(start_tick, 0))
	buffer.put_u8(clampi(crowd_count, 0, 255))
	return buffer.data_array


## `[match_seed, start_tick, crowd_count]`, or `[]` for a payload of the wrong size.
##
## **A SHORT PACKET IS DROPPED WHOLE**, `ScoreWire`'s rule: `StreamPeerBuffer` answers
## a read past the end with zero, and a seed of zero is a *valid* seed — it is what
## `--seed 0` produces — so a truncated payload would not look wrong anywhere. It
## would produce a whole crowd wearing the wrong faces.
static func unpack(bytes: PackedByteArray) -> Array:
	if bytes.size() != SIZE:
		return []
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	return [buffer.get_u64(), buffer.get_u32(), buffer.get_u8()]
