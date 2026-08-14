## Peer lifecycle, role and RTT. `SYS-NET-REPLICATION`, TDD-04 §3, US-0025.
##
## THE ONLY PLACE A PEER IS CREATED OR DESTROYED. Everything else asks this what
## role it is playing and who is connected; nothing else touches
## `multiplayer.multiplayer_peer`, for the same reason `InputMap` has one writer —
## two owners of a connection is two answers to "are we connected".
##
## **THE HANDSHAKE IS A GATE, NOT A GREETING.** A peer that has connected at the
## transport level has proved nothing. It becomes a *player* only after
## `NET-C2S-HELLO` is checked against `Handshake.check()`, and until then the
## server sends it nothing but a welcome or a rejection.
##
## The decisions live in `Handshake` and `Messages`, which are pure; this file is
## the wiring that carries them to a socket. That split is deliberate: every
## branch that decides something is unit-testable with no transport standing up,
## and what is left here is the part only an integration test can reach.
extends Node

## A peer completed the handshake and is a player. Past tense, because by the
## time this fires the roster already contains them.
signal peer_joined(peer: int)

## A peer disconnected, timed out, or was rejected. **The contract cycle repair
## that TDD-04 §3 owes this event is `SYS-CONTRACT`'s and lands in M4.**
signal peer_left(peer: int)

## This client was welcomed. Carries nothing: read `GameState`, which Net has
## already written, rather than passing the same state through two channels.
signal handshake_completed

## This client was refused, with the reason the server gave.
signal handshake_rejected(reason: Messages.Reject)

## True on the dedicated headless server. Every GameSystem checks this before
## instantiating: systems exist ONLY server-side.
var is_server: bool = false

var _peer: ENetMultiplayerPeer = null
var _rtt := RttTable.new()
var _players: Dictionary = {}
var _ping_accum: float = 0.0
var _ping_sent_at: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(false)


## Listen on `port` for at most `max_players` peers. Returns false and logs
## rather than throwing, because a port already in use is an ordinary condition
## on a developer's machine and boot decides what to do about it.
func start_server(port: int, max_players: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players, Messages.CHANNEL_COUNT)
	if err != OK:
		Log.error("Net: cannot listen on port %d (error %d)" % [port, err], &"net")
		return false
	_install(peer, true)
	Log.info(
		(
			"Net: listening on %d, up to %d peers, %d channels"
			% [port, max_players, Messages.CHANNEL_COUNT]
		),
		&"net"
	)
	return true


## Connect to a server. The handshake is sent from `_on_connected_to_server`, not
## from here — at this point nothing has been established but an intention.
func join(address: String, port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, Messages.CHANNEL_COUNT)
	if err != OK:
		Log.error("Net: cannot reach %s:%d (error %d)" % [address, port, err], &"net")
		return false
	_install(peer, false)
	Log.info("Net: connecting to %s:%d" % [address, port], &"net")
	return true


func stop() -> void:
	if _peer != null:
		_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	_players.clear()
	_rtt.clear()
	_ping_sent_at.clear()
	set_process(false)


## Smoothed round-trip time to `peer`, in milliseconds. 0.0 when unknown.
##
## **THE SERVER READS THE TRANSPORT, NOT THE PONGS.** ENet measures RTT on every
## packet it acknowledges; a pong measures it once a second and carries a
## timestamp the client chose. Lag compensation rewinds the world by an amount
## derived from this number, so it must not be one a client can inflate
## (ADR-0010). Clients have no such option — nobody replicates the server's view
## back to them — so they use their own smoothed samples.
func rtt_ms(peer: int) -> float:
	if is_server and _peer != null:
		var enet := _peer.get_peer(peer)
		if enet != null:
			return float(enet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		return 0.0
	return _rtt.rtt_ms(peer)


## Peers that finished the handshake. Not "peers connected": a socket is not a
## player until it has been checked.
func player_count() -> int:
	return _players.size()


func has_player(peer: int) -> bool:
	return _players.has(peer)


func _install(peer: ENetMultiplayerPeer, as_server: bool) -> void:
	_peer = peer
	is_server = as_server
	multiplayer.multiplayer_peer = peer
	set_process(not as_server)


## `TUN-NET-TIMEOUT` on an individual ENet connection.
##
## Applied per peer rather than globally because that is the only place ENet
## exposes it. The three arguments are a retransmission limit and a floor and
## ceiling in milliseconds; pinning the floor and the ceiling to the same value
## is what makes the tunable mean what TUNABLES says it means, instead of a
## number ENet is free to back off from.
func _apply_timeout(peer_id: int) -> void:
	if _peer == null:
		return
	var enet := _peer.get_peer(peer_id)
	if enet == null:
		return
	var ms := int(Tuning.net.timeout * 1000.0)
	enet.set_timeout(ms, ms, ms)


# ----------------------------------------------------------------- transport --


func _on_peer_connected(id: int) -> void:
	_apply_timeout(id)
	if is_server:
		# Nothing is sent yet. The client speaks first, and until it has, this is
		# a socket rather than a player.
		Log.info("Net: peer %d connected, awaiting hello" % id, &"net")


func _on_peer_disconnected(id: int) -> void:
	_forget(id)


func _on_connected_to_server() -> void:
	_apply_timeout(MultiplayerPeer.TARGET_PEER_SERVER)
	_hello.rpc_id(
		MultiplayerPeer.TARGET_PEER_SERVER,
		Messages.PROTOCOL_VERSION,
		Messages.build_hash(),
		Tuning.profile.compute_hash()
	)


func _on_connection_failed() -> void:
	Log.error("Net: connection failed", &"net")
	stop()


func _on_server_disconnected() -> void:
	Log.warn("Net: the server disconnected")
	stop()


func _forget(id: int) -> void:
	var was_player: bool = _players.erase(id)
	_rtt.forget(id)
	_ping_sent_at.erase(id)
	if was_player:
		Log.info("Net: peer %d left" % id, &"net")
		peer_left.emit(id)


# ----------------------------------------------------------------- handshake --

## `NET-C2S-HELLO`. SERVER SIDE. The first thing a peer is allowed to say.
##
## `multiplayer.get_remote_sender_id()`, never a peer id from the payload — the
## sender's identity is the transport's to state, not the sender's to claim.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.SESSION)
func _hello(protocol_version: int, build_hash: int, tuning_hash: int) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	var reason := Handshake.check(protocol_version, build_hash)
	if reason != Messages.Reject.NONE:
		_reject(sender, reason)
		return
	_players[sender] = true
	var server_hash: int = Tuning.profile.compute_hash()
	_welcome.rpc_id(
		sender, sender, server_hash, Messages.MAP_ON_THE_WIRE[Ids.MAP_VETRAIO], GameState.phase
	)
	Log.info("Net: peer %d welcomed — %d player(s)" % [sender, _players.size()], &"net")
	if Handshake.needs_tuning_sync(tuning_hash, server_hash):
		Log.info("Net: peer %d has different tuning — correcting" % sender, &"net")
		_tuning_sync.rpc_id(sender, Tuning.profile.serialise())
	peer_joined.emit(sender)


## Refuse and say why, then close. The reason is sent first and the disconnect is
## deferred, because a peer dropped without one can only report "disconnected" —
## which is what every genuine network fault also looks like.
func _reject(peer: int, reason: Messages.Reject) -> void:
	Log.warn("Net: rejecting peer %d — %s" % [peer, Handshake.reason_text(reason)])
	_rejected.rpc_id(peer, reason)
	_peer.disconnect_peer.call_deferred(peer)


## `NET-S2C-WELCOME`. CLIENT SIDE.
@rpc("authority", "call_remote", "reliable", Messages.Channel.SESSION)
func _welcome(peer_id: int, tuning_hash: int, map_id: int, phase: int) -> void:
	GameState.replace(peer_id, phase as GameState.Phase, GameState.roster)
	Log.info(
		(
			"Net: welcomed as peer %d, map %d, phase %d, tuning %d"
			% [peer_id, map_id, phase, tuning_hash]
		),
		&"net"
	)
	handshake_completed.emit()


## `NET-S2C-TUNING-SYNC`. CLIENT SIDE. **CORRECTED, NEVER KICKED** — the client
## adopts the server's numbers, and `Tuning.adopt()` validates every invariant
## before installing them, so a corrupt profile leaves the client on its own
## values rather than on nonsense.
@rpc("authority", "call_remote", "reliable", Messages.Channel.SESSION)
func _tuning_sync(bytes: PackedByteArray) -> void:
	var incoming := TuningProfile.deserialise(bytes)
	if Tuning.adopt(incoming):
		Log.info("Net: adopted the server's tuning profile", &"net")
	else:
		Log.error("Net: the server's tuning profile was rejected — values now differ", &"net")


## The reject path. CLIENT SIDE. `stop()` is left to the disconnect that follows.
@rpc("authority", "call_remote", "reliable", Messages.Channel.SESSION)
func _rejected(reason: int) -> void:
	Log.error("Net: refused — %s" % Handshake.reason_text(reason as Messages.Reject), &"net")
	handshake_rejected.emit(reason as Messages.Reject)


# ---------------------------------------------------------------- ping / pong --


## Client only, and only once a second. `Messages.PING_INTERVAL` is not a
## tunable: it changes nothing a player perceives, and the server's own RTT does
## not depend on it.
func _process(delta: float) -> void:
	if is_server or _peer == null:
		return
	_ping_accum += delta
	if _ping_accum < Messages.PING_INTERVAL:
		return
	_ping_accum = 0.0
	var now := Time.get_ticks_msec()
	_ping_sent_at[now] = now
	_ping.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, now)


## `NET-C2S-PING`. SERVER SIDE. Echo only — the server stores nothing from this,
## because `client_time` is the client's number and §2.2 forbids trusting it.
@rpc("any_peer", "call_remote", "unreliable", Messages.Channel.STATE)
func _ping(client_time: int) -> void:
	if not is_server:
		return
	_pong.rpc_id(multiplayer.get_remote_sender_id(), client_time, 0)


## `NET-S2C-PONG`. CLIENT SIDE. The round trip is measured against the clock that
## sent it, so an unmatched or replayed timestamp is discarded rather than
## folded in as a wild sample.
@rpc("authority", "call_remote", "unreliable", Messages.Channel.STATE)
func _pong(client_time: int, _server_tick: int) -> void:
	if not _ping_sent_at.erase(client_time):
		return
	_rtt.record(MultiplayerPeer.TARGET_PEER_SERVER, float(Time.get_ticks_msec() - client_time))
