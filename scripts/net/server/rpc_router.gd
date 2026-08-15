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

## The peer has told us which snapshot tick it holds, US-0031. Emitted from the
## input path because that is where the ack rides — `NET-C2S-INPUT`'s
## `acked_tick`, at 60 Hz, costing nothing it was not already spending.
##
## **EMITTED ONLY FOR A COMMAND THAT PASSED THE SEQUENCE GATE.** A stale command
## carries a stale ack, and honouring it would walk a client's baseline
## backwards — harmless, and silently doubling the delta for as long as it kept
## happening.
signal snapshot_acked(peer: int, tick: int)

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
## **PUBLIC SINCE THE DOORWAY MOVED.** TDD-04 §10 names it `_authorise`, and the
## underscore was right while the handlers lived on this node. They live on `Net`
## now — Godot addresses an RPC by node path and `Net` is the only node at the
## same path on both peers — so the chokepoint is called from another object, and
## a private-by-convention method called from outside is worse than an honest
## public one. What has NOT changed is that this is the only thing that decides.
func authorise(peer: int, msg: StringName) -> bool:
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


## What the server thinks the phase is. Read by `Net` to fill
## `NET-S2C-WELCOME` — **which used to send `GameState.phase`, the CLIENT's
## mirror, from the server**, so every joiner was told LOBBY while the match was
## running. Found by reading the log of the first two-process run: `phase 0`.
func phase() -> int:
	return _phase


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


# ------------------------------------------------------------------- routing --

## **`Net` OWNS THE WIRE; THIS OWNS THE DECISION.** US-0030.
##
## These were `@rpc` handlers on this node until the first client tried to send
## one and could not: Godot addresses an RPC by **node path**, and the receiving
## peer looks up the same path. `/root/ServerRoot/NetServer/RpcRouter` does not
## exist on a client, so there was no node to call it from — the handshake worked
## only because `Net` is an autoload at `/root/Net` on both peers.
##
## The doorway moved to `Net` and the decision stayed here. Every handler there
## calls `authorise()` first and `test_no_client_authority.gd` still refuses one
## that does not.


## An authorised input, in sequence. Returns false if the gate dropped it —
## which is not an error and is not logged: UDP reorders, and a late packet is
## the transport working as designed.
func receive_input(peer: int, command: InputCommand) -> bool:
	if not _sequence.accept(peer, command.seq):
		return false
	snapshot_acked.emit(peer, command.acked_tick)
	input_received.emit(peer, command)
	return true


func receive_ability_request(peer: int, slot: int, origin: Vector3, direction: Vector3) -> void:
	ability_requested.emit(peer, slot, origin, direction)


func receive_blend_request(peer: int, target_id: int) -> void:
	blend_requested.emit(peer, target_id)
