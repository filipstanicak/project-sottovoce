## The wire surface: channels, protocol version, and what may never be sent.
## NETWORK_PROTOCOL §1.1 and §2.1, TDD-04 §3.1 and §6.
##
## PURE. No node, no peer, no engine state — so every rule below is a unit test
## with no transport standing up.
##
## **THE CHANNEL A MESSAGE TRAVELS ON IS A PROPERTY OF THE MESSAGE**, declared
## here once, rather than an argument each caller passes. A snapshot sent down
## the reliable channel by a caller who typed the wrong number is a bug that
## looks like packet loss: it works perfectly until the network is bad, which is
## the one condition the split exists for.
class_name Messages
extends RefCounted

## ENet channels. The numbers are the wire, so they are pinned, not inferred.
##
## `STATE` is unreliable because a retransmitted snapshot arrives *after* a
## fresher one and is worthless; `EVENT` and `SESSION` are reliable ordered
## because a lost score is a score that never happened.
enum Channel { STATE = 0, EVENT = 1, SESSION = 2 }

## Why a handshake was refused. `NONE` is the accept case, so a caller that
## forgets to check gets a value that is obviously not a reason.
##
## `LOBBY_FULL` is **appended, not inserted**: the ordinals travel on the wire in
## the rejection message. ENet already refuses a connection past `max_clients`,
## so this is close to unreachable — but "close to" is not "never", and a
## `--max-players` larger than `TUN-LOBBY-MAX-PLAYERS` reaches it exactly.
enum Reject { NONE, PROTOCOL_VERSION, BUILD_HASH, LOBBY_FULL }

## How many ENet channels the peer is created with. Not `Channel.size()`: the
## count passed to `create_server` is a transport parameter, and reading it off
## an enum would silently follow a fourth channel nobody sized the peer for.
const CHANNEL_COUNT := 3

## Bumped whenever a payload in §2 or §3 changes shape. A client that disagrees
## is rejected at `NET-C2S-HELLO` rather than being allowed to misread every
## packet after it.
const PROTOCOL_VERSION := 1

## How often a client sends `NET-C2S-PING`. The catalogue's rate column, and
## **not a tunable**: it changes nothing a player can perceive. The server does
## not depend on it — see `Net.rtt_ms`.
const PING_INTERVAL := 1.0

## Map ids on the wire. `NET-S2C-WELCOME` carries a `u8`, and this is where the
## corpus's `MAP-` ID becomes that byte — the number belongs to the protocol, the
## ID belongs to the corpus, and neither should have to know the other's shape.
const MAP_ON_THE_WIRE: Dictionary = {
	Ids.MAP_VETRAIO: 0,
}

## Every message that exists, and the channel it belongs to.
##
## Absence from this table is meaningful: `channel_for()` refuses an unknown ID
## rather than defaulting to `STATE`, so a message invented in code but never
## documented cannot reach the wire.
##
## **`NET-S2C-COMPASS` IS DELIBERATELY ABSENT AND IS NOT SETTLED.** GDD-03's
## acceptance criteria name it as a payload to inspect; the protocol catalogue has
## no row for it, and TDD-04 §10 says compass data is per-observer and rides in
## the snapshot. Two readings, one of which means a message that does not exist.
## Giving it a channel here would settle a design question by implementation, so
## it gets `-1` until whoever builds `SYS-COMPASS` decides. Recorded in US-0025.
const CHANNEL_FOR: Dictionary = {
	# Handshake, lobby, join and leave. Low volume, correctness-critical.
	Ids.NET_C2S_HELLO: Channel.SESSION,
	Ids.NET_C2S_LOADOUT: Channel.SESSION,
	Ids.NET_C2S_READY: Channel.SESSION,
	Ids.NET_C2S_SKIP_RESULTS: Channel.SESSION,
	Ids.NET_S2C_WELCOME: Channel.SESSION,
	Ids.NET_S2C_TUNING_SYNC: Channel.SESSION,
	Ids.NET_S2C_LOBBY_STATE: Channel.SESSION,
	Ids.NET_S2C_MATCH_START: Channel.SESSION,
	Ids.NET_S2C_PLAYER_JOINED: Channel.SESSION,
	Ids.NET_S2C_PLAYER_LEFT: Channel.SESSION,
	# The high-volume stream. Stale data is worthless, so never retransmitted.
	Ids.NET_C2S_INPUT: Channel.STATE,
	Ids.NET_C2S_PING: Channel.STATE,
	Ids.NET_S2C_SNAPSHOT: Channel.STATE,
	Ids.NET_S2C_PONG: Channel.STATE,
	# Outcomes. Must arrive, and must arrive in order.
	Ids.NET_C2S_ABILITY_REQUEST: Channel.EVENT,
	Ids.NET_C2S_BLEND_REQUEST: Channel.EVENT,
	Ids.NET_S2C_CONTRACT_ASSIGNED: Channel.EVENT,
	Ids.NET_S2C_KILL_RESULT: Channel.EVENT,
	Ids.NET_S2C_STUN_RESULT: Channel.EVENT,
	Ids.NET_S2C_ABILITY_STARTED: Channel.EVENT,
	Ids.NET_S2C_ABILITY_DENIED: Channel.EVENT,
	Ids.NET_S2C_PREY_WARNING: Channel.EVENT,
	Ids.NET_S2C_SCORE_EVENT: Channel.EVENT,
	Ids.NET_S2C_PHASE_CHANGED: Channel.EVENT,
	Ids.NET_S2C_MATCH_END: Channel.EVENT,
}

## **MESSAGES THAT MUST NEVER EXIST**, NETWORK_PROTOCOL §2.1.
##
## `Ids` declares these five because the corpus *names* them, in the paragraph
## explaining that they are absent — the harvest cannot tell a prohibition from a
## specification. So the prohibition is declared here, the way a retired input
## action is declared dead in `InputActions.DEPRECATED`.
##
## A client cannot express "I killed someone" in this protocol. Kill and stun are
## **buttons in the input bitfield**, evaluated server-side against the
## lag-compensated world, and that single fact is what lets SCOPE_FENCE OUT #9
## defer all anti-cheat beyond server authority.
const FORBIDDEN: Array[StringName] = [
	Ids.NET_C2S_KILL,
	Ids.NET_C2S_STUN,
	Ids.NET_C2S_POSITION,
	Ids.NET_C2S_SUSPICION,
	Ids.NET_C2S_SCORE,
]


## The channel `id` travels on. `-1` for anything not in the table above.
static func channel_for(id: StringName) -> int:
	return CHANNEL_FOR.get(id, -1)


static func is_forbidden(id: StringName) -> bool:
	return FORBIDDEN.has(id)


## What two peers must agree on before either can read the other's packets.
##
## **DERIVED FROM THE PROTOCOL SURFACE, NOT FROM A BUILD STAMP.** The corpus asks
## for a `build_hash:u64` and never says where it comes from; a CI-stamped build
## id would reject two builds that differ in a shader and accept two that differ
## in the wire format, which is backwards. This hashes the things a mismatch
## actually breaks — the version, the message catalogue and the button bitfield's
## order — so it is computable identically on both peers with no build system at
## all. Recorded as an open question in US-0025.
static func build_hash() -> int:
	var surface: Array = [PROTOCOL_VERSION, CHANNEL_COUNT]
	for id: StringName in CHANNEL_FOR.keys():
		surface.append("%s:%d" % [id, CHANNEL_FOR[id]])
	for bit: int in InputBits.ALL:
		surface.append(bit)
	return hash(surface)
