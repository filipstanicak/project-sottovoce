## Peer lifecycle, role, RTT, and **every message on the wire**.
## `SYS-NET-REPLICATION`, TDD-04 §3, US-0025 and US-0030.
##
## THE ONLY PLACE A PEER IS CREATED OR DESTROYED, and — since the doorway moved
## here — the only node that answers an RPC. Both for the same reason: this is
## the one node at the same path on every peer.
##
## **THE HANDSHAKE IS A GATE, NOT A GREETING.** A peer that has connected at the
## transport level has proved nothing; it becomes a *player* only after
## `NET-C2S-HELLO` is checked against `Handshake.check()`.
##
## The decisions live elsewhere and every one of them is pure: `Handshake`
## admits, `Authority` and `RpcRouter` authorise, `PeerRegistry` remembers,
## `Snapshot` encodes. **This file is the wiring that carries them to a socket**,
## and it is deliberately the only part that needs a transport to test.
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

## A snapshot arrived. CLIENT SIDE. Carries the decoded object, because every
## listener would otherwise decode the same bytes again.
signal snapshot_received(snapshot: Snapshot)

## True on the dedicated headless server. Every GameSystem checks this before
## instantiating: systems exist ONLY server-side.
var is_server: bool = false

## Reassembles delta snapshots into whole ones. Public so a reconnect can clear it.
var assembler := SnapshotAssembler.new()

var _peer: ENetMultiplayerPeer = null
var _peers := PeerRegistry.new()
var _router: RpcRouter = null
var _pings := PingClock.new()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# **A CHILD OF THIS AUTOLOAD IS AT THE SAME PATH ON EVERY PEER**, which is
	# what lets an RPC surface live somewhere other than this file. `PingClock`
	# is the first to use it; the C2S doorway below could move the same way if
	# this file grows again.
	_pings.name = "PingClock"
	_pings.setup(_peers)
	add_child(_pings)


## Listen on `port` for at most `max_players` peers. Returns false and logs
## rather than throwing: a port already in use is an ordinary condition on a
## developer's machine, and boot decides what to do about it.
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


## Connect to a server. The handshake is sent from `_on_connected_to_server`:
## nothing is established here but an intention.
func join(address: String, port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, Messages.CHANNEL_COUNT)
	if err != OK:
		Log.error("Net: cannot reach %s:%d (error %d)" % [address, port, err], &"net")
		return false
	_install(peer, false)
	Log.info("Net: connecting to %s:%d" % [address, port], &"net")
	return true


## **THE DOORWAY NEEDS THE DECIDER.** Called once by `server_root.gd`; until it
## is, every C2S handler refuses everything.
func bind_router(router: RpcRouter, slots: SlotTable = null) -> void:
	_router = router
	_peers.use_slots(slots)


## The wire identity of `peer`, or `SlotTable.NO_SLOT`.
func slot_of(peer: int) -> int:
	return _peers.slot_of(peer)


func peer_of(slot: int) -> int:
	return _peers.peer_of(slot)


func stop() -> void:
	if _peer != null:
		_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	_peers.clear()
	_pings.clear()


## Smoothed round-trip time to `peer`, in milliseconds. 0.0 when unknown.
##
## **THE SERVER READS THE TRANSPORT, NOT THE PONGS** — ENet measures on every
## packet it acknowledges, and a pong carries a timestamp the client chose.
## `rtt_table.gd` has the argument in full.
func rtt_ms(peer: int) -> float:
	if is_server and _peer != null:
		var enet := _peer.get_peer(peer)
		if enet != null:
			return float(enet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		return 0.0
	return _peers.rtt_ms(peer)


## Whether this peer is a client with a live connection.
##
## **EVERYTHING THAT SENDS MUST ASK FIRST.** With no peer at all, Godot's own
## caller id is 1, so `rpc_id(1, ...)` addresses the sender and fails — which is
## every test in this repo, none of which stands up a transport. Found the moment
## the ping heartbeat moved to its own node and stopped being switched off with
## `set_physics_process`.
func is_client_connected() -> bool:
	if is_server or _peer == null:
		return false
	return _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Peers that finished the handshake — a socket is not a player until checked.
func player_count() -> int:
	return _peers.player_count()


func has_player(peer: int) -> bool:
	return _peers.has_player(peer)


func _install(peer: ENetMultiplayerPeer, as_server: bool) -> void:
	_peer = peer
	is_server = as_server
	multiplayer.multiplayer_peer = peer


## `TUN-NET-TIMEOUT` on every connection this host currently holds.
##
## Per connection, because that is the only place ENet exposes it. The three
## arguments are a retransmission limit and a floor and ceiling in milliseconds;
## pinning floor and ceiling to the same value is what makes the tunable mean
## what TUNABLES says rather than a number ENet is free to back off from.
##
## **THROUGH THE HOST, NOT THROUGH `get_peer(id)`.** This used to look the peer
## up by id, which works on a server — where `peers` is keyed by unique id — and
## **never worked on a client at all**: a client's map is empty, `get_peer(1)`
## fails its own `ERR_FAIL_COND`, and every client logged
## `Condition "!peers.has(p_id)" is true` on connect. The early return meant
## nothing broke, so the only symptom was **the client silently using ENet's
## default timeout instead of the tunable**. Measured: on a connected client
## `get_peers()` is empty while `host.get_peers()` holds one peer in state
## `CONNECTED`.
##
## Applying to all of them is idempotent, and it removes the id lookup that was
## the wrong idea in the first place.
func _apply_timeout() -> void:
	if _peer == null or _peer.host == null:
		return
	var ms := int(Tuning.net.timeout * 1000.0)
	for connection: ENetPacketPeer in _peer.host.get_peers():
		connection.set_timeout(ms, ms, ms)


# ----------------------------------------------------------------- transport --


func _on_peer_connected(id: int) -> void:
	_apply_timeout()
	if is_server:
		# The client speaks first; until it has, this is a socket, not a player.
		Log.info("Net: peer %d connected, awaiting hello" % id, &"net")


func _on_peer_disconnected(id: int) -> void:
	_forget(id)


func _on_connected_to_server() -> void:
	_apply_timeout()
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
	var was_player := _peers.forget(id)
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
	var slot := _peers.admit(sender)
	if slot == SlotTable.NO_SLOT:
		Log.warn("Net: peer %d arrived with the lobby full" % sender)
		_reject(sender, Messages.Reject.LOBBY_FULL)
		return
	var server_hash: int = Tuning.profile.compute_hash()
	# **THE SLOT, NOT THE PEER ID** — `NET-S2C-WELCOME` declares `peer_id:u8`.
	# **THE ROUTER'S PHASE, NOT `GameState`'s.** `GameState` is the CLIENT's
	# read-only mirror; reading it here sent every joiner LOBBY while the match
	# was running. The server's own answer lives with the thing that gates rules
	# on it. Found in the log of the first two-process run — `phase 0`.
	_welcome.rpc_id(
		sender, slot, server_hash, Messages.MAP_ON_THE_WIRE[Ids.MAP_VETRAIO], _router.phase()
	)
	Log.info("Net: peer %d welcomed — %d player(s)" % [sender, _peers.player_count()], &"net")
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


# ------------------------------------------------------- the C2S doorway --

## **WHY THE HANDLERS LIVE HERE AND NOT ON `RpcRouter`.** Godot addresses an RPC
## by **node path** and the receiving peer looks up the same path;
## `/root/ServerRoot/NetServer/RpcRouter` does not exist on a client, so there
## was no node to call it from and `NET-C2S-INPUT` was unsendable. This autoload
## is at `/root/Net` on both peers, which is why the handshake worked at all.
##
## The doorway is here; **the decision is still the router's**. Every handler
## calls `authorise()` first and `test_no_client_authority.gd` refuses one that
## does not.

## `NET-C2S-INPUT`. SERVER SIDE, 60 Hz. The sender is the transport's to state,
## never the payload's to claim.
@rpc("any_peer", "call_remote", "unreliable", Messages.Channel.STATE)
func c2s_input(seq: int, move: Vector2, yaw: float, pitch: float, buttons: int, tick: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _router == null or not _router.authorise(peer, Ids.NET_C2S_INPUT):
		return
	var command := InputCommand.new()
	command.seq = seq
	command.move = move
	command.look_yaw = yaw
	command.look_pitch = pitch
	command.buttons = buttons
	command.acked_tick = tick
	_router.receive_input(peer, command)


## `NET-C2S-ABILITY-REQUEST`. Aim is clamped by `SYS-ABILITY`, not here.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.EVENT)
func c2s_ability_request(slot: int, origin: Vector3, direction: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _router == null or not _router.authorise(peer, Ids.NET_C2S_ABILITY_REQUEST):
		return
	_router.receive_ability_request(peer, slot, origin, direction)


## `NET-C2S-BLEND-REQUEST`. Range and capacity belong to `SYS-BLEND`.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.EVENT)
func c2s_blend_request(target_id: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _router == null or not _router.authorise(peer, Ids.NET_C2S_BLEND_REQUEST):
		return
	_router.receive_blend_request(peer, target_id)


## Send one sampled command upstream. `InputSender` calls this once per physics
## frame.
func send_input(command: InputCommand) -> void:
	if not is_client_connected():
		return
	(
		c2s_input
		. rpc_id(
			MultiplayerPeer.TARGET_PEER_SERVER,
			command.seq,
			command.move,
			command.look_yaw,
			command.look_pitch,
			command.buttons,
			# **FROM THE ASSEMBLER, NOT THE COMMAND.** The command is replayed during
			# reconciliation; a network value stamped on it would enter replay input.
			assembler.newest_tick()
		)
	)


# ------------------------------------------------------ the snapshot stream --


## Send one client its snapshot. SERVER SIDE, at `TUN-NET-SNAPSHOT-RATE`.
func send_snapshot(peer: int, snapshot: Snapshot) -> void:
	if not is_server or _peer == null:
		return
	s2c_snapshot.rpc_id(peer, snapshot.serialise())


## `NET-S2C-SNAPSHOT`. CLIENT SIDE. **Unreliable by design**: a retransmitted
## snapshot arrives after a fresher one and is worthless. A buffer that does not
## decode is dropped in silence rather than applied partially.
@rpc("authority", "call_remote", "unreliable", Messages.Channel.STATE)
func s2c_snapshot(bytes: PackedByteArray) -> void:
	# **ASSEMBLED FIRST**: delta encoding stops here. See `SnapshotAssembler`.
	var snapshot := assembler.assemble(Snapshot.deserialise(bytes))
	if snapshot == null:
		return
	snapshot_received.emit(snapshot)
