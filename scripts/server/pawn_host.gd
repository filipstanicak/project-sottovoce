## **THE AUTHORITATIVE PAWNS.** TDD-04 §2, TDD-06 §1, US-0028. SERVER ONLY.
##
## One `PawnServer` per connected peer, spawned on join and freed on leave, each
## driven by the inputs that peer sent — through the **same** `PawnStateMachine`,
## the same `PawnState` classes and the same `PawnMotion` the client predicts
## with (ADR-0008).
##
## **THE CLIENT NEVER WRITES POSITION, VELOCITY OR STATE.** It sends intent; this
## is where intent becomes an outcome. There is no path by which a client's
## number reaches `ctx.position` — the only thing that arrives from the wire is
## an `InputCommand`, and every field of it is a button or a stick.
##
## **SPAWN SELECTION IS NOT HERE.** `SYS-SPAWN` (US-0062) decides *where* a pawn
## appears, from the contract cycle and the crowd. This places a pawn at a
## declared spawn point so that M2 has something to replicate, and picking the
## index round-robin is a placeholder that says so.
class_name PawnHost
extends Node3D

## A pawn was spawned or freed. `SYS-SPAWN` and the snapshot builder will care;
## the router already does, because a peer with no pawn may not send input.
signal pawn_spawned(peer: int)
signal pawn_freed(peer: int)

const PAWN_SERVER := "res://scenes/pawn/pawn_server.tscn"

var _ctx: MatchContext
var _pawns: Dictionary = {}
var _scene: PackedScene
var _next_spawn: int = 0


func setup(ctx: MatchContext) -> void:
	_ctx = ctx
	_scene = load(PAWN_SERVER) as PackedScene
	if _scene == null:
		Log.error("PawnHost cannot load %s" % PAWN_SERVER, &"pawn")


## Give `peer` a pawn. Idempotent: a second hello from a peer that already has
## one must not leave two pawns simulating against the same inputs.
func spawn(peer: int) -> bool:
	if _scene == null or _pawns.has(peer):
		return false
	var pawn := _scene.instantiate() as CharacterBody3D
	pawn.name = "Pawn_%d" % peer
	add_child(pawn)
	var record := _build_record(peer, pawn)
	if record.is_empty():
		pawn.queue_free()
		return false
	_pawns[peer] = record
	_ctx.pawns[peer] = pawn
	_ctx.pawn_contexts[peer] = record["ctx"] as PawnContext
	Log.info(
		"pawn spawned for peer %d at %v" % [peer, (record["ctx"] as PawnContext).position], &"pawn"
	)
	pawn_spawned.emit(peer)
	return true


## Wire one pawn's parts and place it. Returns {} if the scene is not the shape
## `pawn_server.tscn` promises — which is a broken export, not a bad peer.
func _build_record(peer: int, pawn: CharacterBody3D) -> Dictionary:
	var machine := pawn.get_node_or_null("PawnStateMachine") as PawnStateMachine
	var probes := pawn.get_node_or_null("TraversalProbes") as TraversalProbes
	if machine == null or probes == null:
		Log.error("pawn_server.tscn is missing its state machine or probes", &"pawn")
		return {}
	var ctx := PawnContext.new()
	# **DECLARED IN M1 AND NEVER WRITTEN UNTIL US-0053.** Nothing read it, so
	# nothing was wrong — and the first thing that would have (`SYS-BLEND` asking
	# `CrowdFormations` which slot this player holds) would have asked about peer
	# **zero**, which `group_of_peer` answers with the first *unclaimed* group.
	# A confidently wrong answer rather than an empty one, and every test would
	# have passed because tests set the field.
	ctx.peer_id = peer
	ctx.body = pawn
	ctx.reset_for_spawn(_spawn_point(), 0.0)
	if not machine.spawn_into(ctx, PawnStateId.IDLE):
		return {}
	pawn.global_position = ctx.position
	return {"peer": peer, "pawn": pawn, "ctx": ctx, "machine": machine, "probes": probes}


## Take `peer`'s pawn away. Called on disconnect and on timeout alike — TDD-04 §3
## treats them as the same event, because from the server's side they are.
func despawn(peer: int) -> void:
	if not _pawns.has(peer):
		return
	var record: Dictionary = _pawns[peer]
	(record["pawn"] as Node).queue_free()
	_pawns.erase(peer)
	_ctx.pawns.erase(peer)
	_ctx.pawn_contexts.erase(peer)
	Log.info("pawn freed for peer %d" % peer, &"pawn")
	pawn_freed.emit(peer)


## Apply one command to one pawn, at the input rate. Connected to
## `MatchDirector.input_applied`, which decides *when* and *how many times*.
func apply_input(peer: int, command: InputCommand, dt: float) -> void:
	if not _pawns.has(peer):
		return
	var record: Dictionary = _pawns[peer]
	PawnMotion.advance(
		record["ctx"] as PawnContext,
		record["machine"] as PawnStateMachine,
		record["probes"] as TraversalProbes,
		record["pawn"] as CharacterBody3D,
		command,
		dt
	)


## The authoritative context for `peer`, or null. Read-only to everything else:
## this is the state the snapshot is built from, and a second writer would put
## two answers on the wire.
func context_for(peer: int) -> PawnContext:
	if not _pawns.has(peer):
		return null
	return (_pawns[peer] as Dictionary)["ctx"] as PawnContext


func has_pawn(peer: int) -> bool:
	return _pawns.has(peer)


func pawn_count() -> int:
	return _pawns.size()


## Round-robin over the map's declared points. **A PLACEHOLDER, AND IT SAYS SO**
## — `SYS-SPAWN` owns the real decision, which reads the contract cycle and the
## crowd, and putting any part of that rule here would be a rule in the wrong
## layer.
func _spawn_point() -> Vector3:
	if _ctx == null or _ctx.map == null or _ctx.map.spawn_count() == 0:
		return Vector3.ZERO
	var index := _next_spawn % _ctx.map.spawn_count()
	_next_spawn += 1
	return _ctx.map.spawn_points[index]
