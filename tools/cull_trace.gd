## **WHY THE CULL BOUNDARY STILL CHURNS.** US-0030, US-0045, TDD-04 §7.1.3.
##
## A live watch left one finding unexplained: four to six NPCs per spawn point
## created and freed about once per snapshot, each last seen at **70.01-70.05 m**
## against a 70.00 m radius. `test_cull_jitter.gd` drives the two cases that
## reproduce deterministically — a body parked on the line, and one walking
## straight out through it — and both are quiet.
##
## **THE LIVE PROBE CAN ONLY SEE THE CLIENT HALF.** It reports which NPC was
## dropped and how far away it was last seen; it cannot say what the server
## decided about that NPC on the tick before, which is the half that would name
## the cause. This tool holds both ends in one process.
##
## It boots the real `server_root.tscn`, seats a full lobby, and for every tick
## **round-trips each snapshot through `serialise()`/`deserialise()`** so the
## positions it judges are the quantised ones a client actually receives.
##
## **IT DRIVES SIX REAL `NpcView`s, NOT A COPY OF THEIR RULES.** A diagnostic that
## reimplements the thing it is diagnosing measures its own copy, and the copy is
## the one place a defect cannot be. The views are the shipping class, fed the
## bytes a client would receive; for every drop this prints the **server's** own
## view of that NPC over the surrounding ticks, which is the half the live probe
## cannot see.
##
## **HEADLESS IS CORRECT HERE**, unlike `crowd_probe.gd`, which refuses it: this
## measures numbers, not pixels, and needs no window and no input device.
##
##     godot --headless --path . res://tools/cull_trace.tscn
##
## **IT IS A SCENE AND NOT A `-s` SCRIPT.** A `SceneTree` script compiles before
## the autoload globals are registered, so every script naming `Net` fails to
## compile and the server silently boots without them.
extends Node

const SERVER_ROOT := "res://scenes/server_root.tscn"
const PLAYERS := 6
const WARMUP := 40
const TICKS := 240

## How stale the acknowledgement is. Zero is the timing that hid a dead delta for
## a whole story: an ack lags by at least a tick on any real connection, and three
## is the order of `TUN-NET-INTERP-BUFFER` at the snapshot rate.
const ACK_LAG := 3

## Ticks of server-side context printed either side of a drop.
const CONTEXT := 4

var _root: Node
var _director: MatchDirector
var _snapshots: SnapshotBuilder
var _crowd: NpcPool
var _tick := 0
var _clients: Dictionary = {}
var _peers: PackedInt32Array = PackedInt32Array()
var _drops: Array = []
var _trace: Dictionary = {}
var _appeared: Dictionary = {}
var _received: Dictionary = {}
var _built: Dictionary = {}
var _assemblers: Dictionary = {}
var _acks: Dictionary = {}


func _traced_rows() -> int:
	var total := 0
	for peer: int in _trace.keys():
		for index: int in (_trace[peer] as Dictionary).keys():
			total += ((_trace[peer] as Dictionary)[index] as Array).size()
	return total


func _dropped_by(peer: int) -> int:
	var total := 0
	for drop: Array in _drops:
		if int(drop[0]) == peer:
			total += 1
	return total


func _ready() -> void:
	_root = (load(SERVER_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	_run()


func _run() -> void:
	await get_tree().physics_frame
	_director = _root.get_node("MatchDirector") as MatchDirector
	_snapshots = _root.get_node("NetServer/SnapshotBuilder") as SnapshotBuilder
	_crowd = _root.get_node("World/Crowd") as NpcPool
	for _i: int in 200:
		await get_tree().physics_frame
		if _crowd.active_count() > 0:
			break
	# **THE SHIPPED SEND IS UNHOOKED, NOT DUPLICATED.** `send_all` builds a
	# snapshot per client and discards it without an ENet peer; building a second
	# one here would advance the delta twice per tick and measure a connection
	# receiving everything in duplicate.
	_director.tick_completed.disconnect(_snapshots.send_all)
	for seat: int in PLAYERS:
		Net.peer_joined.emit(9100 + seat)
		_peers.append(9100 + seat)
	for peer: int in _peers:
		_clients[peer] = _a_client(peer)
		_assemblers[peer] = SnapshotAssembler.new()
	_director.tick_completed.connect(_on_tick)
	for _i: int in (WARMUP + TICKS) * 2:
		await get_tree().physics_frame
	_report()
	Net.bind_router(null, null)
	get_tree().quit(0)


## One real `NpcView`, detached from `Net`. It subscribes to `snapshot_received`
## in `_ready()`, which is right in a client scene and wrong here: six of them
## would each answer every peer's snapshot. They are fed by hand instead.
func _a_client(peer: int) -> NpcView:
	var view := NpcView.new()
	view.name = "View_%d" % peer
	add_child(view)
	Net.snapshot_received.disconnect(view.apply_snapshot)
	view.npc_appeared.connect(
		func(_i: int) -> void: _appeared[peer] = int(_appeared.get(peer, 0)) + 1
	)
	view.npc_dropped.connect(_on_dropped.bind(peer, view))
	return view


## **READ BEFORE THE ERASE.** `NpcView` emits this signal while the record is
## still there precisely so a listener can ask where the NPC was; reading after it
## returns the default, which is what the first crowd probe did and why it
## reported the same distance for every flapper.
func _on_dropped(index: int, peer: int, view: NpcView) -> void:
	var at := view.last_seen(index)
	var away := (
		-1.0
		if at == Vector3.INF
		else Vector2(at.x, at.z).distance_to(Vector2(view.observer().x, view.observer().z))
	)
	var cull: float = Tuning.net.npc_cull_radius
	var rule := "rule 1 (farewell)" if away <= cull + view.drop_margin() else "rule 2 (safety)"
	_drops.append([peer, _tick, index, away, rule])


func _on_tick(_ctx: MatchContext, _dt: float) -> void:
	_tick += 1
	for peer: int in _peers:
		var built := _snapshots.build_for(peer)
		# **`deserialise` IS STATIC AND RETURNS A NEW SNAPSHOT.** Calling it on an
		# instance and discarding the result leaves an empty one, which reads exactly
		# like a server sending no crowd — 39 115 records built, 0 delivered.
		# **`deserialise` IS STATIC AND RETURNS A NEW SNAPSHOT.** Calling it on an
		# instance and discarding the result leaves an empty one, which reads exactly
		# like a server sending no crowd.
		var wire := Snapshot.deserialise(built.serialise())
		_note_server_view(peer, built)
		if _tick > WARMUP:
			# **THROUGH THE ASSEMBLER, BECAUSE THAT IS THE CLIENT'S REAL PATH.** `Net`
			# assembles before it emits `snapshot_received`, so a view fed raw wire
			# snapshots is being driven through a route no client uses. Feeding them
			# directly is what made the first version of this tool report a clean
			# boundary over the exact defect it was written to find.
			var assembler := _assemblers[peer] as SnapshotAssembler
			var whole := assembler.assemble(wire)
			_built[peer] = int(_built.get(peer, 0)) + built.npcs.size()
			if whole != null:
				_received[peer] = int(_received.get(peer, 0)) + whole.npcs.size()
				(_clients[peer] as NpcView).apply_snapshot(whole)
			_ack(peer, assembler)


## **THE ACK IS WHAT THE CLIENT ASSEMBLED, DELAYED.** `Net` acknowledges
## `SnapshotAssembler.newest_tick()` and never the tick that merely arrived, so a
## harness acking an invented number tells the server to delta against a baseline
## the client refused — and every snapshot after it is unappliable. Measured that
## way: 505 records built where the same run built 36 788.
##
## The queue is the wire. In one process an ack is instant, which is the single
## timing that hid a dead NPC delta for a whole story, so it is held for `ACK_LAG`
## ticks on the way back.
func _ack(peer: int, assembler: SnapshotAssembler) -> void:
	if not _acks.has(peer):
		_acks[peer] = PackedInt32Array()
	var queue: PackedInt32Array = _acks[peer]
	queue.append(assembler.newest_tick())
	if queue.size() > ACK_LAG:
		_snapshots.note_ack(peer, queue[0])
		queue.remove_at(0)
	_acks[peer] = queue


## What the server believed about every NPC this tick, kept per peer so a drop can
## be explained afterwards. Recomputed from the same two facts `_choose` used —
## the pool's live position and the observer's — rather than by instrumenting
## shipping code.
func _note_server_view(peer: int, built: Snapshot) -> void:
	var crowd := _crowd
	var eye := built.own_position
	var sent: Dictionary = {}
	for record: Array in built.npcs:
		sent[int(record[0])] = true
	if not _trace.has(peer):
		_trace[peer] = {}
	var rows: Dictionary = _trace[peer]
	for index: int in crowd.active_count():
		var at := crowd.position_of(index)
		var away := Vector2(at.x - eye.x, at.z - eye.z).length()
		if absf(away - Tuning.net.npc_cull_radius) > 2.0:
			continue
		if not rows.has(index):
			rows[index] = []
		var row: Array = rows[index]
		(
			row
			. append(
				[
					_tick,
					away,
					sent.has(index),
					_snapshots.crowd_delta.holds(peer, index),
				]
			)
		)


func _report() -> void:
	print("--- the cull boundary, both ends, %d ticks at an ack lag of %d ---" % [TICKS, ACK_LAG])
	if not _saw_anything():
		return
	var per_peer: Dictionary = {}
	for drop: Array in _drops:
		var key: String = "%d/%d" % [drop[0], drop[2]]
		per_peer[key] = int(per_peer.get(key, 0)) + 1
	for peer: int in _peers:
		var view: NpcView = _clients[peer]
		print(
			(
				"peer %d at (%.1f, %.1f): %d drawn, %d appeared, %d dropped"
				% [
					peer,
					view.observer().x,
					view.observer().z,
					view.count(),
					int(_appeared.get(peer, 0)),
					_dropped_by(peer),
				]
			)
		)
	_report_worst(per_peer)


## **THE GUARD AGAINST A CLEAN REPORT OVER NOTHING, AND IT EARNED ITS PLACE
## IMMEDIATELY.** "No drops at all" is what a quiet boundary prints and what a tool
## that never received a snapshot prints. The first run reported a perfect boundary
## over **36 788 records built and 0 delivered** — `Snapshot.deserialise` is static
## and returns a new snapshot, and calling it on an instance throws the result
## away.
func _saw_anything() -> bool:
	var records := 0
	var made := 0
	for peer: int in _peers:
		records += int(_received.get(peer, 0))
		made += int(_built.get(peer, 0))
	print(
		(
			"ticks observed %d, records built %d, delivered to a view %d, boundary rows %d"
			% [_tick, made, records, _traced_rows()]
		)
	)
	if _tick > 0 and records > 0:
		return true
	print("THIS TOOL SAW NOTHING. Nothing below is evidence about the cull.")
	return false


func _report_worst(per_peer: Dictionary) -> void:
	var worst: Array = []
	for key: String in per_peer:
		worst.append([int(per_peer[key]), key])
	if worst.is_empty():
		print("NO DROPS AT ALL. Either the churn is gone or this tool cannot see it.")
		return
	worst.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	print("%d (peer, NPC) pairs dropped; the worst:" % worst.size())
	for i: int in mini(3, worst.size()):
		var parts := (worst[i][1] as String).split("/")
		_explain(int(parts[0]), int(parts[1]), int(worst[i][0]))


## **THE SERVER'S OWN VIEW AROUND EVERY DROP.** A distance and a rule name say
## which line was crossed; only the ticks either side say why it was crossed
## twice.
func _explain(peer: int, index: int, times: int) -> void:
	print("  peer %d, Npc_%d dropped %d times" % [peer, index, times])
	var when: Array = []
	for drop: Array in _drops:
		if int(drop[0]) == peer and int(drop[2]) == index:
			when.append(drop)
	for drop: Array in when.slice(0, 3):
		print("    dropped at tick %d, %.4f m away, %s" % [drop[1], drop[3], drop[4]])
		_print_rows(peer, index, int(drop[1]))


func _print_rows(peer: int, index: int, at_tick: int) -> void:
	var rows: Array = (_trace.get(peer, {}) as Dictionary).get(index, [])
	for row: Array in rows:
		if absi(int(row[0]) - at_tick) > CONTEXT:
			continue
		print(
			(
				"      tick %4d  server %.4f m  sent %s  held %s"
				% [row[0], row[1], "yes" if row[2] else " no", "yes" if row[3] else " no"]
			)
		)
