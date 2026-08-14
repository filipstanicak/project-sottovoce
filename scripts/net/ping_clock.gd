## **THE CLIENT'S OWN RTT ESTIMATE.** NETWORK_PROTOCOL §2–3, US-0025.
##
## `NET-C2S-PING` out at `Messages.PING_INTERVAL`, `NET-S2C-PONG` back, and the
## round trip folded into `PeerRegistry`.
##
## **A CHILD OF THE `Net` AUTOLOAD, AND THAT IS WHAT MAKES IT REACHABLE.** Godot
## addresses an RPC by node path and the receiving peer looks up the same path;
## `Net` is at `/root/Net` on every peer, so **anything `Net` creates in
## `_ready()` is at the same path on every peer too**. That is the general answer
## to where an RPC surface may live, and this is the first thing to use it — the
## alternative was one autoload growing without limit.
##
## **THE SERVER DOES NOT DEPEND ON THIS.** It reads ENet's own continuously
## measured statistic instead, because `client_time` is client-supplied and
## therefore forgeable, and lag compensation rewinds by an amount derived from
## RTT (ADR-0010). This is the client measuring its own connection, which nobody
## else is going to tell it about.
class_name PingClock
extends Node

var _peers: PeerRegistry
var _accum: float = 0.0
var _sent_at: Dictionary = {}


func setup(peers: PeerRegistry) -> void:
	_peers = peers


## Client only, once a second. `Messages.PING_INTERVAL` is not a tunable: it
## changes nothing a player perceives.
##
## `_physics_process`, never `_process` — a heartbeat on rendered frames samples
## at whatever rate the hardware chooses, feeding a filter whose window then
## differs per machine.
func _physics_process(delta: float) -> void:
	if not Net.is_client_connected():
		return
	_accum += delta
	if _accum < Messages.PING_INTERVAL:
		return
	_accum = 0.0
	var now := Time.get_ticks_msec()
	_sent_at[now] = now
	c2s_ping.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, now)


## `NET-C2S-PING`. SERVER SIDE. Echo only — the server stores nothing from this,
## because `client_time` is the client's number and §2.2 forbids trusting it.
## Its authority column reads "none needed", which is why it is in the guard's
## `PRE_AUTHORITY` list rather than calling the chokepoint.
@rpc("any_peer", "call_remote", "unreliable", Messages.Channel.STATE)
func c2s_ping(client_time: int) -> void:
	if not Net.is_server:
		return
	s2c_pong.rpc_id(multiplayer.get_remote_sender_id(), client_time, 0)


## `NET-S2C-PONG`. CLIENT SIDE. Measured against the clock that sent it, so an
## unmatched or replayed timestamp is discarded rather than folded in.
@rpc("authority", "call_remote", "unreliable", Messages.Channel.STATE)
func s2c_pong(client_time: int, _server_tick: int) -> void:
	if _peers == null or not _sent_at.erase(client_time):
		return
	_peers.record_rtt(
		MultiplayerPeer.TARGET_PEER_SERVER, float(Time.get_ticks_msec() - client_time)
	)


func clear() -> void:
	_sent_at.clear()
	_accum = 0.0
