## **THE PIECES OF THE LOOP, EACH DRIVEN FOR REAL.** US-0030.
##
## The whole loop needs two processes — `Net` is an autoload, so one process
## holds one of it — and that is US-0036's harness. What one process *can* do is
## drive each half against real objects: a real `SnapshotBuilder` reading real
## server pawns, and a real `RemotePawns` reading the bytes that builder
## produced.
##
## **THE BYTES ARE NOT SKIPPED.** Every case below serialises and deserialises,
## because the format is where the information rules live and a test that passed
## objects between the halves would prove nothing about what actually travels.
extends GutTest

const MAP_COLLISION := "res://scenes/map/map_vetraio_collision.tscn"
const A := 1660290033
const B := 400847904

var _host: PawnHost
var _builder: SnapshotBuilder
var _ctx: MatchContext


func before_each() -> void:
	add_child_autofree((load(MAP_COLLISION) as PackedScene).instantiate())
	_ctx = MatchContext.new()
	_ctx.map = load("res://data/maps/map_vetraio.tres") as MapData
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame


## Give both peers a pawn and a wire slot, the way a handshake would — without
## one, because a handshake needs a peer on the other end and this is one process.
func _two_players() -> void:
	for peer: int in [A, B]:
		_ctx.slots.assign(peer)
		_host.spawn(peer)


func test_a_snapshot_carries_the_other_player_and_not_the_observer() -> void:
	# **A CLIENT THAT RECEIVED ITSELF AS A REMOTE PAWN** would render a second
	# copy of itself 100 ms in the past — memorable to look at, tedious to explain.
	_two_players()
	var snapshot := _builder.build_for(A)
	assert_eq(snapshot.remote_pawns.size(), 1, "the observer is in their own snapshot")
	assert_eq(
		(snapshot.remote_pawns[0] as Array)[0], _ctx.slots.slot_of(B), "the wrong slot was sent"
	)


func test_the_observers_own_pawn_is_full_and_unquantised() -> void:
	_two_players()
	var own := _host.context_for(A)
	var snapshot := _builder.build_for(A)
	assert_almost_eq(snapshot.own_position.x, own.position.x, 0.0001, "own position was rounded")
	assert_eq(snapshot.own_state, own.state_id)


func test_the_snapshot_survives_the_wire_and_places_a_remote_pawn() -> void:
	# **THE ASSERTION THE FILE IS FOR.** Builder to bytes to decoder to a node in
	# the tree, with nothing in between doubled.
	_two_players()
	var bytes := _builder.build_for(A).serialise()
	var decoded := Snapshot.deserialise(bytes)
	assert_not_null(decoded, "the snapshot did not survive the wire")

	var remotes: RemotePawns = RemotePawns.new()
	add_child_autofree(remotes)
	remotes.set_own_slot(_ctx.slots.slot_of(A))
	remotes.apply_snapshot(decoded)
	assert_eq(remotes.count(), 1, "the other player did not appear")
	assert_true(remotes.has_slot(_ctx.slots.slot_of(B)), "the wrong slot appeared")


func test_a_remote_pawn_moves_where_the_server_put_it() -> void:
	_two_players()
	var remotes: RemotePawns = RemotePawns.new()
	add_child_autofree(remotes)
	remotes.set_own_slot(_ctx.slots.slot_of(A))
	remotes.apply_snapshot(Snapshot.deserialise(_builder.build_for(A).serialise()))
	# **NOTHING MOVES ON `apply_snapshot` SINCE US-0034.** The snapshot records
	# where a pawn WAS; the render clock decides when to draw it. One physics
	# frame is what turns the first into the second.
	await get_tree().physics_frame

	var server_position := _host.context_for(B).position
	var node := remotes.get_node("PawnRemote_%d" % _ctx.slots.slot_of(B)) as Node3D
	assert_not_null(node, "the remote pawn node is not named after its slot")
	assert_almost_eq(
		node.global_position.distance_to(server_position),
		0.0,
		Tuning.net.quant_pos * 2.0,
		"the remote pawn is not where the server said"
	)


func test_a_player_who_stops_appearing_is_freed() -> void:
	# **ABSENCE IS THE SIGNAL.** There is no "player left" record in the snapshot:
	# a client that missed one reliable message would keep a ghost forever, where
	# a client that misses one snapshot recovers on the next.
	_two_players()
	var remotes: RemotePawns = RemotePawns.new()
	add_child_autofree(remotes)
	remotes.set_own_slot(_ctx.slots.slot_of(A))
	remotes.apply_snapshot(Snapshot.deserialise(_builder.build_for(A).serialise()))
	assert_eq(remotes.count(), 1, "the premise failed")

	_host.despawn(B)
	remotes.apply_snapshot(Snapshot.deserialise(_builder.build_for(A).serialise()))
	assert_eq(remotes.count(), 0, "a departed player left a ghost")


func test_an_alone_player_sees_nobody() -> void:
	_ctx.slots.assign(A)
	_host.spawn(A)
	assert_eq(_builder.build_for(A).remote_pawns.size(), 0)


func test_the_input_sender_pushes_every_sampled_command() -> void:
	# **NO GATE OF ITS OWN.** Sending only commands that "changed" would look like
	# a saving and would break the server's repeat rule: a client that stopped
	# sending while standing still would keep walking on the server.
	# **INSTANTIATED FROM THE SCRIPT, NOT FROM THE GLOBAL NAME.** `InputSender.
	# new()` returns a `RefCounted` here — the global class cache resolves the
	# name to something that is not the `Node` the file declares, and the same
	# script typed twice produces "trying to assign input_sender.gd to
	# input_sender.gd". Loading the resource is unambiguous and is what the scene
	# does anyway.
	var script := load("res://scripts/net/client/input_sender.gd") as GDScript
	var sender: Node = script.new()
	for i: int in 5:
		sender._on_command_sampled(InputCommand.empty(i))
	assert_eq(sender.sent_count(), 5, "a sampled command was not sent")
