## **THE `SESSION`-CHANNEL SERVER-TO-CLIENT MESSAGES, ON THEIR OWN NODE.**
## `NETWORK_PROTOCOL.md` §3, US-0101. A child of the `Net` autoload.
##
## **SPLIT FROM `EventWire` WHEN `NET-S2C-LOBBY-STATE` WOULD NOT FIT.** That class
## reached `.gdlintrc`'s twenty public methods, and the split had a line waiting for
## it: `NET-S2C-MATCH-START` was built there on 2026-09-13 while riding `SESSION`,
## not `EVENT` — so the file whose docstring called itself the `EVENT`-channel
## doorway held one message that was not. Both messages here are the catalogue's
## `X` rows, reliable, and ordered after `NET-S2C-WELCOME` on the same channel:
## a late joiner is welcomed, told who wears what (`MatchConsequences.peer_joined`)
## and then the seed (`MatchAnnouncer.started_for`). The wardrobe's gate makes the
## order irrelevant to what is drawn; this says which one is built.
##
## **THE TWO MESSAGES ARE THE TWO HALVES `Wardrobe` WAITS FOR**, which is the other
## reason they belong together: the seed dresses the crowd and the roster dresses
## the players, and the client dresses nobody until it holds both.
class_name SessionWire
extends Node

## `NET-S2C-MATCH-START` arrived. CLIENT SIDE. **`GameState` already holds it** by
## the time this fires; the signal is for anything that must rebuild rather than
## re-read. `Wardrobe`, which dresses the clones from the seed, re-reads instead —
## on `GameState.state_replaced`, because it needs this *and* the roster.
signal match_started(match_seed: int, start_tick: int, crowd_count: int)


## **`NET-S2C-MATCH-START`, AND IT IS SENT ONCE PER PEER RATHER THAN ONCE PER
## MATCH.** The catalogue's *once* column is about the recipient: a player who joins
## while a match is running needs the seed exactly as much as one who was there at
## the countdown, and would otherwise draw a crowd nobody else can see the same way.
func send_match_start(peer: int, match_seed: int, start_tick: int, crowd: int) -> void:
	if not Net.is_server:
		return
	s2c_match_start.rpc_id(peer, MatchStartWire.pack(match_seed, start_tick, crowd))


## `NET-S2C-MATCH-START`. CLIENT SIDE.
##
## **RELIABLE, BECAUSE THERE IS NO SECOND CHANCE AND NO WAY TO NOTICE.** A dropped
## seed is a client whose whole crowd wears the wrong faces, for the rest of the
## match, with nothing on screen saying so — every NPC still walks, still blends,
## still hides somebody. It is the quietest packet loss in this protocol.
##
## **ON `SESSION` RATHER THAN `EVENT`, AND THE ORDER IS THE REASON.** A late joiner
## is welcomed from the handshake and told the seed from `peer_joined` a moment
## later; only on the same ordered channel as `NET-S2C-WELCOME` is the second
## guaranteed to land after the first. The catalogue has said X since M0.
@rpc("authority", "call_remote", "reliable", Messages.Channel.SESSION)
func s2c_match_start(payload: PackedByteArray) -> void:
	var fields := MatchStartWire.unpack(payload)
	if fields.is_empty():
		Log.error("malformed match-start payload: %d bytes" % payload.size(), &"net")
		return
	GameState.adopt_match(int(fields[0]), int(fields[1]), int(fields[2]))
	match_started.emit(int(fields[0]), int(fields[1]), int(fields[2]))


## `NET-S2C-LOBBY-STATE`, SERVER SIDE: every seat and the persona in it, US-0101.
## One pack, N sends, `send_match_end`'s shape — the roster is the same for everyone.
func send_lobby_state(peers: Array, payload: PackedByteArray) -> void:
	if not Net.is_server:
		return
	for peer: int in peers:
		s2c_lobby_state.rpc_id(peer, payload)


## `NET-S2C-LOBBY-STATE`. CLIENT SIDE. **On `SESSION`, `NET-S2C-MATCH-START`'s
## channel, for the same order argument**: a late joiner is welcomed, told the seed
## and told the roster, and the wardrobe dresses nobody until it holds both.
@rpc("authority", "call_remote", "reliable", Messages.Channel.SESSION)
func s2c_lobby_state(payload: PackedByteArray) -> void:
	var fields := LobbyStateWire.unpack(payload)
	if fields.is_empty():
		Log.error("malformed lobby-state payload: %d bytes" % payload.size(), &"net")
		return
	GameState.adopt_personas(fields[0])
