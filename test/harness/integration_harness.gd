## **A REAL SERVER AND REAL CLIENTS, IN ONE PROCESS.** US-0036, TDD-12.
##
## Not a mock, and the story says why: *a mock cannot surface prediction bugs,
## because the bug IS the difference between two real implementations of the same
## step function.* So every object here is the shipping one — `client_root.tscn`
## with its real `LocalPawnDriver` and `Reconciler`, a real `PawnHost` driving
## `pawn_server.tscn`, a real `SnapshotBuilder`, and the real `Snapshot` bytes
## between them.
##
## **ONLY THE WIRE IS SYNTHETIC**, and only because it has to be: `Net` is an
## autoload, so one process holds exactly one of it, and an RPC resolves by node
## path. The harness carries commands and snapshots between the halves itself,
## holding each for a chosen number of frames — which is also what makes latency
## a dial rather than a network condition nobody can reproduce.
##
## **WHAT IT DOES NOT DO: PER-CLIENT INPUT.** Every client here samples the same
## global `InputMap`, so they all receive the same command on a given frame. They
## are genuinely different pawns — different spawns, different positions,
## independent histories and reconcilers — but scripted *divergent* input needs an
## injectable sampler, which is its own change and is not pretended to here.
class_name IntegrationHarness
extends RefCounted

const CLIENT_ROOT := "res://scenes/client_root.tscn"
const MAP := "res://data/maps/map_vetraio.tres"

## Frames of one-way delay per profile, at the 60 Hz physics rate. **Test
## parameters, not tunables**: they describe the conditions a test runs under,
## and nothing a player experiences reads them.
##
## | Profile | Frames | ≈ RTT |
## |---|---|---|
## | `LAN` | 1 | ~33 ms |
## | `GOOD` | 3 | ~100 ms |
## | `TYPICAL` | 6 | ~200 ms |
## | `POOR` | 11 | ~370 ms |
const LATENCY: Dictionary = {&"LAN": 1, &"GOOD": 3, &"TYPICAL": 6, &"POOR": 11}

## Every profile, in the order a matrix should walk them.
const PROFILES: Array[StringName] = [&"LAN", &"GOOD", &"TYPICAL", &"POOR"]

var ctx := MatchContext.new()
var host: PawnHost
var builder: SnapshotBuilder

## **WHAT ACTUALLY WENT DOWN THE WIRE.** Delta encoding is only worth having if
## it is measured, and only trustworthy if a test can tell a delta stream from a
## stream of full snapshots that happens to pass every other assertion.
var snapshot_bytes: int = 0
var full_snapshots: int = 0
var delta_snapshots: int = 0

var _tree: SceneTree
var _owner: Node
var _clients: Dictionary = {}
var _created: Array[Node] = []
var _latency: int = 1
var _frame: int = 0
var _in_flight: Array = []


## Stand the server up. `owner` is the test, which adopts every node so GUT frees
## them; `profile` is one of `PROFILES`.
func start(tree: SceneTree, owner: Node, profile: StringName = &"LAN") -> void:
	_tree = tree
	_owner = owner
	_latency = int(LATENCY.get(profile, 1))

	ctx = MatchContext.new()
	ctx.map = load(MAP) as MapData
	# ACTIVE because `SYS-MATCH` is M4's and a server in LOBBY authorises no input
	# and simulates nothing — see `server_root.gd`.
	ctx.phase = MatchPhase.Phase.ACTIVE

	host = PawnHost.new()
	_adopt(host)
	host.setup(ctx)

	builder = SnapshotBuilder.new()
	_adopt(builder)
	builder.setup(ctx, host, null)


## Add one client: a real `client_root.tscn`, a real server pawn, and the wire
## between them.
##
## The server pawn is moved to the client's own spawn so the two start agreeing —
## disagreeing at frame zero would make every later assertion measure the setup
## rather than the netcode.
func add_client(peer: int) -> void:
	var root := (load(CLIENT_ROOT) as PackedScene).instantiate()
	_adopt(root)
	var driver := root.get_node("LocalPawnDriver") as LocalPawnDriver
	var reconciler := root.get_node("ClientNet/Reconciler") as Reconciler

	ctx.slots.assign(peer)
	host.spawn(peer)
	var server := host.context_for(peer)
	server.reset_for_spawn(driver.ctx.position, driver.ctx.yaw)
	(server.body as CharacterBody3D).global_position = server.position

	# **EACH CLIENT GETS ITS OWN ASSEMBLER**, because each acknowledges on its own
	# schedule and a shared one would hand a peer a baseline only another received.
	# In the shipping client this lives on `Net`; one process holds one of those,
	# so the harness owns them per peer — the same reason the wire is synthetic.
	_clients[peer] = {
		"root": root,
		"driver": driver,
		"reconciler": reconciler,
		"assembler": SnapshotAssembler.new(),
	}
	driver.command_sampled.connect(func(command: InputCommand) -> void: _uplink(peer, command))


## Take a client away, the way a disconnect does.
##
## **EVERY OWNER OF PER-PEER STATE IS TOLD, IN ONE PLACE** — the same list
## `server_root.gd` walks on `Net.peer_left`. ENet reuses peer ids, so anything
## left behind is inherited by the next joiner: a stale slot names them as
## somebody else in every message that names anybody, and a stale pawn keeps
## simulating with nobody driving it.
##
## In-flight packets for the departing peer are dropped rather than delivered. A
## snapshot arriving for a client that has gone is not a case the real code can
## see — the socket is closed — so delivering one would test a situation that
## cannot happen.
func remove_client(peer: int) -> void:
	if not _clients.has(peer):
		return
	host.despawn(peer)
	ctx.slots.release(peer)
	builder.forget(peer)
	var root := _clients[peer]["root"] as Node
	_clients.erase(peer)
	_created.erase(root)
	root.queue_free()

	var still: Array = []
	for packet: Array in _in_flight:
		if int(packet[1]) != peer:
			still.append(packet)
	_in_flight = still


## How many packets are still on the wire. A churn test reads this to prove the
## harness itself is not the thing leaking.
func in_flight() -> int:
	return _in_flight.size()


func has_client(peer: int) -> bool:
	return _clients.has(peer)


## **THE HARNESS OWNS EVERY NODE IT MAKES**, and frees them itself.
##
## GUT frees a test instance between scripts, not between tests, so anything
## parented to the test survives into the next one — three clients would become
## six, all still driven, all still sampling the same input. The first version of
## this file let the caller adopt the nodes as well and added each of them twice.
func _adopt(node: Node) -> void:
	_owner.add_child(node)
	_created.append(node)


## Free everything. Called from the test's `after_each`.
func tear_down() -> void:
	release_everything()
	for node: Node in _created:
		node.queue_free()
	_created.clear()
	_clients.clear()
	_in_flight.clear()


## A client's sampled command, on its way to the server. Held for the profile's
## latency, exactly as a packet would be.
##
## **A DEPARTED CLIENT SENDS NOTHING.** `queue_free()` frees at the end of the
## frame, so a removed client's driver samples once more and would enqueue a
## packet nobody can deliver. Guarding at the source is also what really happens:
## a closed socket does not send. The churn test found this by watching the
## in-flight count fail to return to zero.
func _uplink(peer: int, command: InputCommand) -> void:
	if not _clients.has(peer):
		return
	# **STAMPED AT SEND, NOT AT SAMPLE**, the same as `Net.send_input`: the
	# acknowledged tick is a fact about the wire, and the command object is
	# replayed during reconciliation.
	var outgoing := command.duplicate_command()
	outgoing.acked_tick = (_clients[peer]["assembler"] as SnapshotAssembler).newest_tick()
	_in_flight.append([_latency, peer, outgoing, true, null])


## Deliver everything that has landed, and hold the rest one frame longer.
func _pump_wire() -> void:
	var still: Array = []
	for packet: Array in _in_flight:
		if int(packet[0]) > 0:
			still.append([int(packet[0]) - 1, packet[1], packet[2], packet[3], packet[4]])
			continue
		if bool(packet[3]):
			_arrive_upstream(int(packet[1]), packet[2] as InputCommand)
		else:
			_arrive_downstream(int(packet[1]), packet[4] as PackedByteArray)
	_in_flight = still


## The server receives a command, applies it, and answers with a snapshot — which
## then has to travel back, and waits its own latency to do so.
func _arrive_upstream(peer: int, command: InputCommand) -> void:
	if not _clients.has(peer):
		return
	# **THE ACK RIDES THE INPUT**, exactly as `NET-C2S-INPUT` carries it, so the
	# delta path here is the shipping one rather than a full send every tick.
	builder.note_ack(peer, command.acked_tick)
	host.apply_input(peer, command, MatchContext.step_dt())
	var snapshot := builder.build_for(peer)
	snapshot.last_acked_seq = command.seq
	# **SERIALISED, NOT HANDED OVER.** The format is where the information rules
	# live, so a harness that passed objects would prove nothing about what
	# actually travels.
	var bytes := snapshot.serialise()
	snapshot_bytes += bytes.size()
	if snapshot.baseline_age == Snapshot.FULL:
		full_snapshots += 1
	else:
		delta_snapshots += 1
	_in_flight.append([_latency, peer, null, false, bytes])


func _arrive_downstream(peer: int, bytes: PackedByteArray) -> void:
	if not _clients.has(peer):
		return
	# Assembled before anything sees it, the way `Net.s2c_snapshot` does — a
	# partial snapshot must never reach gameplay code, here or in the client.
	var assembler := _clients[peer]["assembler"] as SnapshotAssembler
	var snapshot := assembler.assemble(Snapshot.deserialise(bytes))
	if snapshot == null:
		return
	(_clients[peer]["reconciler"] as Reconciler)._on_snapshot_received(snapshot)


## Advance the whole system by `frames` physics frames, pumping the wire on each.
func advance(frames: int) -> void:
	for _i: int in frames:
		_advance_server_clock()
		_pump_wire()
		await _tree.physics_frame


## **THE SERVER'S CLOCK, DERIVED THE WAY `MatchDirector` DERIVES IT** — one net
## tick every second physics frame, counted rather than timed.
##
## **IT DID NOT ADVANCE AT ALL UNTIL US-0031**, so every snapshot the harness
## ever built carried `server_tick = 0`. Nothing depended on it and nothing
## failed: the reconciler orders by `last_acked_seq`, not by tick. Delta encoding
## was the first thing to read it, and it read a client whose newest assembled
## tick was permanently zero — so the ack was zero, no baseline was ever usable,
## and **the server sent a full snapshot every tick while the whole suite passed.**
## Caught by `test_the_stream_really_contains_deltas` on its first run, which is
## the only assertion in that file that could have caught it.
func _advance_server_clock() -> void:
	_frame += 1
	if _frame < 2:
		return
	_frame = 0
	ctx.tick += 1


## Hold an action down for `frames`, then release it. The harness's only way to
## drive input, and it drives every client at once — see the class docstring.
func drive(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await advance(frames)
	Input.action_release(action)


## **THE ASSERTION THE HARNESS EXISTS FOR.** The largest reconciliation error any
## client has been asked to absorb, in metres — comparable against
## `TUN-NET-RECONCILE-THRESHOLD`.
func worst_reconciliation_error() -> float:
	var worst := 0.0
	for peer: int in _clients:
		worst = maxf(worst, reconciliation_error(peer))
	return worst


## How far the server's answer was from what this client had predicted **for the
## same command**. Zero means the two peers agree exactly.
##
## **THIS IS THE NUMBER, AND `prediction_lead` IS NOT.** Read from the
## reconciler, which compares the snapshot against the client's own stored state
## at `last_acked_seq` — the only comparison in which both sides describe the same
## moment.
func reconciliation_error(peer: int) -> float:
	if not _clients.has(peer):
		return INF
	return (_clients[peer]["reconciler"] as Reconciler).last_error


## **HOW FAR AHEAD THE CLIENT HAS PREDICTED. NOT AN ERROR.** The distance between
## the client's live position and the server's live position.
##
## In a predicting architecture the client is *always* ahead — it simulates input
## the instant it is pressed and the server has not seen it yet — so this is a
## measure of the lead, and a healthy one is non-zero.
##
## **IT WAS CALLED `disagreement()` AND COMPARED AGAINST
## `TUN-NET-RECONCILE-THRESHOLD` IN THREE TESTS**, which is a category error that
## passed only because the pawn walked. Measured: **0.0733 m at stroll and
## 0.1500 m at run — exactly 2.00 commands at both**, against a 0.10 m threshold,
## while the reconciler's own error was **0.00000 m over 120 samples**. So the
## assertions were one speed rung away from failing over a defect that did not
## exist. Trap 4 again, in the harness written to catch trap 4.
func prediction_lead(peer: int) -> float:
	var server := host.context_for(peer)
	if server == null:
		return INF
	var driver := _clients[peer]["driver"] as LocalPawnDriver
	return driver.ctx.position.distance_to(server.position)


func driver_for(peer: int) -> LocalPawnDriver:
	return _clients[peer]["driver"] as LocalPawnDriver


func reconciler_for(peer: int) -> Reconciler:
	return _clients[peer]["reconciler"] as Reconciler


func client_count() -> int:
	return _clients.size()


## Release every bound action. Called by the test's teardown, because a held key
## leaks into the next test and moves a pawn nobody asked to move.
static func release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)
