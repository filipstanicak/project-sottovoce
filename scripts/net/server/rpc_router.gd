## **THE AUTHORITY CHOKEPOINT.** TDD-04 §2 and §10, US-0026. SERVER ONLY.
##
## Every inbound client message arrives here and nowhere else, is authorised
## here, and reaches a system only as a signal this node emits. There is no path
## around it — `test_no_client_authority.gd` scans the source and fails if one
## appears.
##
## **THE ROUTER DECIDES NOTHING ABOUT THE GAME.** It answers one question — *may
## this peer be saying this, now* — and hands what survives to whoever is
## listening. Whether the ability is off cooldown, whether the kill lands,
## whether the target is in range: all of that is a system's, and all of it needs
## world state this node deliberately cannot see. Keeping the two apart is what
## makes the authority rule checkable by reading rather than by reasoning.
##
## **SIGNALS, NOT CALLS.** The router does not know `SYS-COMBAT` exists. US-0028
## connects the server pawn simulation to `input_received`; nothing here changes
## when it does. A router that called systems directly would have to be edited
## every time one was added, and each edit is a chance to add a handler that
## forgets to authorise.
class_name RpcRouter
extends Node

## An authorised input from a peer who owns a pawn, in sequence.
signal input_received(peer: int, command: InputCommand)

## An authorised ability request. **A REQUEST, NEVER AN ACTIVATION** — the
## ability system decides, and may deny.
signal ability_requested(peer: int, slot: int, aim_origin: Vector3, aim_dir: Vector3)

## An authorised blend request.
signal blend_requested(peer: int, target_id: int)

## Something was refused. Carries the reason so a test can assert *why* rather
## than only that nothing happened.
signal message_denied(peer: int, msg: StringName, denial: Authority.Denial)

var _sequence := SequenceGate.new()
var _players: Dictionary = {}
var _pawn_owners: Dictionary = {}
var _phase: int = GameState.Phase.LOBBY


## **THE ROUTER KEEPS ITS OWN ROSTER, FED BY `Net`'S SIGNALS.**
##
## It could ask `Net.has_player()` on every message instead, and that was the
## first shape. It is worse for a reason worth writing down: a router whose
## answers come from a global cannot be *asked a question* in a test — every
## assertion collapses to "the peer is not a player", which is true whatever the
## phase and pawn tracking are doing. Three tests passed that way and proved
## nothing. State the router owns is state a test can set.
func _ready() -> void:
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(forget)


func _on_peer_joined(peer: int) -> void:
	set_player(peer, true)


## Record that `peer` completed the handshake. Called from `Net.peer_joined`; a
## test calls it directly, which is the point.
func set_player(peer: int, admitted: bool) -> void:
	if admitted:
		_players[peer] = true
	else:
		_players.erase(peer)


## The one entry point. **EVERY C2S HANDLER CALLS THIS FIRST**, and the guard
## refuses a handler that does not.
##
## Named with an underscore in TDD-04 §10's interface and kept that way: it is
## not for callers outside this node, and a public `authorise()` would be an
## invitation to authorise something somewhere else.
func _authorise(peer: int, msg: StringName) -> bool:
	var denial := Authority.check(msg, _players.has(peer), _phase, _pawn_owners.has(peer))
	if denial == Authority.Denial.NONE:
		return true
	Log.warn("net: refused %s from peer %d — %s" % [msg, peer, Authority.denial_text(denial)])
	message_denied.emit(peer, msg, denial)
	return false


## The server's own phase. Written by `MatchDirector` in M4; until then the
## router is told, rather than reading a client-side mirror it must never trust.
func set_phase(phase: int) -> void:
	_phase = phase


## Record that `peer` owns a living pawn. US-0028 calls this on spawn; nothing
## else may, because "does this peer have a pawn" is the last authority question
## and a second writer would give it two answers.
func set_pawn_owner(peer: int, owns: bool) -> void:
	if owns:
		_pawn_owners[peer] = true
	else:
		_pawn_owners.erase(peer)


## Forget everything about a peer that left. Called from `Net.peer_left`, and it
## matters because ENet reuses peer ids: a stale sequence number would make the
## next joiner's input arrive in the past for eighteen minutes.
func forget(peer: int) -> void:
	_sequence.forget(peer)
	_players.erase(peer)
	_pawn_owners.erase(peer)


## The last input sequence accepted from `peer`, for the snapshot header.
func last_acked_seq(peer: int) -> int:
	return _sequence.last_seen(peer)


# ------------------------------------------------------------------ handlers --

## `NET-C2S-INPUT`. **THE SENDER'S PAWN, LOOKED UP FROM THE PEER ID.**
##
## Nothing in the payload names a pawn, and the sender cannot name themselves:
## the peer id comes from the transport, which is the only participant with no
## reason to lie. That single fact is why there is no "which pawn" field to
## validate — the question cannot be asked in this protocol.
##
## **THE FIELDS ARRIVE AS ARGUMENTS, NOT AS A `PackedByteArray`.** TDD-04 §10
## sketches a packed payload, and that is right — but packing it means choosing
## the quantisation (`TUN-NET-QUANT-POS`, `TUN-NET-QUANT-YAW`) and the u16/i8
## widths of §6.3, which is **US-0029's** decision and not one this story has any
## basis to make. A placeholder format invented here is a format US-0029 would
## have to delete, and would be on the wire in the meantime. §10 is a sketch of
## interfaces; §6.3 is the wire, and it stays unwritten until its own story.
@rpc("any_peer", "call_remote", "unreliable", Messages.Channel.STATE)
func c2s_input(seq: int, move: Vector2, yaw: float, pitch: float, buttons: int, tick: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not _authorise(peer, Ids.NET_C2S_INPUT):
		return
	if not _sequence.accept(peer, seq):
		# Not an error and not logged as one. UDP reorders; a late packet is the
		# transport working as designed, and logging each one would bury the
		# refusals that mean something.
		return
	var command := InputCommand.new()
	command.seq = seq
	command.move = move
	command.look_yaw = yaw
	command.look_pitch = pitch
	command.buttons = buttons
	command.client_tick = tick
	input_received.emit(peer, command)


## `NET-C2S-ABILITY-REQUEST`. Aim is clamped server-side by the ability system —
## §2's authority column — not here.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.EVENT)
func c2s_ability_request(slot: int, aim_origin: Vector3, aim_dir: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not _authorise(peer, Ids.NET_C2S_ABILITY_REQUEST):
		return
	ability_requested.emit(peer, slot, aim_origin, aim_dir)


## `NET-C2S-BLEND-REQUEST`. Range and capacity belong to `SYS-BLEND`.
@rpc("any_peer", "call_remote", "reliable", Messages.Channel.EVENT)
func c2s_blend_request(target_id: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not _authorise(peer, Ids.NET_C2S_BLEND_REQUEST):
		return
	blend_requested.emit(peer, target_id)
