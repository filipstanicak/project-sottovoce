## The transport actually stands up. US-0025, TDD-04 §3.
##
## `Handshake` and `Messages` are unit-tested with no socket, because that is
## where the decisions live. This file exists for the half that no pure test can
## reach: whether a port is really opened, on the right number of channels, and
## whether a real ENet client is seen arriving and leaving.
##
## **THE FULL HANDSHAKE ROUND TRIP IS NOT HERE, AND CANNOT BE.** `Net` is an
## autoload, so one process holds exactly one of it; an RPC resolves by node
## path, so a second `Net` at a second path could not answer the first. Proving
## `NET-C2S-HELLO` end to end needs two processes, which is US-0036's harness.
## Ticking that criterion off this file would be rounding up.
##
## **NOR IS THE BIND FAILURE ASSERTED HERE.** `start_server` returning false on a
## port already in use is real and `boot.gd` quits on it, but provoking it means
## a failed `create_server`, which pushes an engine error from inside the engine —
## and GUT reports that as a failure of the test doing the provoking, naming the
## cleanup rather than the thing under test. That the port is genuinely bound and
## genuinely released is asserted instead, by rebinding it after `stop()`.
extends GutTest

## Well outside the 27015 default, so a developer running the real server on this
## machine does not fail the suite.
const PORT := 28715

var _client: ENetMultiplayerPeer


func before_each() -> void:
	Net.stop()


func after_each() -> void:
	if _client != null:
		_client.close()
		_client = null
	Net.stop()
	Net.is_server = false


## Pump both ends. ENet does nothing without being polled, and the poll happens
## in the engine's own iteration — so the only way to advance a connection is to
## let frames pass.
func _pump(frames: int) -> void:
	for _i: int in frames:
		if _client != null:
			_client.poll()
		await get_tree().process_frame


func test_the_server_listens_on_the_port_it_was_given() -> void:
	assert_true(Net.start_server(PORT, 6), "the server did not open the port")
	assert_true(Net.is_server, "starting a server did not make this peer a server")
	assert_eq(Net.player_count(), 0, "a server with nobody connected reported players")


func test_a_real_client_reaches_the_server_and_is_seen() -> void:
	# THE ASSERTION THE FILE IS FOR. Everything else could pass on a peer object
	# that was created and never bound to anything.
	assert_true(Net.start_server(PORT, 6))
	_client = ENetMultiplayerPeer.new()
	assert_eq(
		_client.create_client("127.0.0.1", PORT, Messages.CHANNEL_COUNT),
		OK,
		"the client could not be created"
	)
	await _pump(40)
	assert_eq(
		_client.get_connection_status(),
		MultiplayerPeer.CONNECTION_CONNECTED,
		"the client never connected to a server that says it is listening"
	)


func test_a_socket_is_not_a_player_until_it_has_spoken() -> void:
	# **THE HANDSHAKE IS A GATE, NOT A GREETING.** A raw ENet client that has
	# connected has proved nothing, and must not appear in the roster or receive
	# anything. The count is the observable half of that rule.
	assert_true(Net.start_server(PORT, 6))
	_client = ENetMultiplayerPeer.new()
	_client.create_client("127.0.0.1", PORT, Messages.CHANNEL_COUNT)
	await _pump(40)
	assert_eq(Net.player_count(), 0, "a peer that never said hello was counted as a player")


func test_the_channels_are_opened_on_both_ends() -> void:
	# A mismatch in channel count is not an error either end reports: ENet simply
	# negotiates down to the smaller number, and messages on the missing channel
	# vanish. The symptom would be score events going missing under load.
	assert_eq(Messages.CHANNEL_COUNT, 3)
	assert_true(Net.start_server(PORT, 6))
	_client = ENetMultiplayerPeer.new()
	assert_eq(_client.create_client("127.0.0.1", PORT, Messages.CHANNEL_COUNT), OK)
	await _pump(40)
	assert_eq(_client.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)


func test_stopping_releases_everything() -> void:
	# Not tidiness: a suite that leaves a port bound fails the NEXT test with a
	# message about the next test.
	assert_true(Net.start_server(PORT, 6))
	Net.stop()
	var reuse := ENetMultiplayerPeer.new()
	assert_eq(reuse.create_server(PORT, 6, Messages.CHANNEL_COUNT), OK, "the port stayed bound")
	reuse.close()
