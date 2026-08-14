## **THE OTHER PLAYERS, AS THE SERVER LAST DESCRIBED THEM.** TDD-01 §3.2.
## CLIENT ONLY.
##
## One `pawn_remote.tscn` per slot in the snapshot, created when a slot first
## appears and freed when it stops appearing. No state machine, no navigation
## agent, no collision — TDD-06 §1 rule 2: a remote pawn that simulated would
## produce a second, wrong answer that disagrees with the server's.
##
## **RENDERED `TUN-NET-INTERP-BUFFER` IN THE PAST**, between the two snapshots
## that bracket that moment (US-0034). It snapped at 30 Hz when the loop first
## closed, deliberately — seeing the wire before the thing that smooths it is
## what keeps a replication bug from hiding inside an interpolator.
##
## **`_physics_process`, NOT `_process`.** Interpolating on rendered frames would
## be marginally smoother on a 144 Hz display and would put a moving transform on
## a clock the player's hardware chooses; the fixed clock is already twice the
## snapshot rate. `test_no_gameplay_in_process.gd` refuses the other one under
## `scripts/net/` outright, and it is right to.
class_name RemotePawns
extends Node3D

## A slot appeared or vanished. Past tense; the node already exists or is gone.
signal remote_appeared(slot: int)
signal remote_vanished(slot: int)

const PAWN_REMOTE := "res://scenes/pawn/pawn_remote.tscn"

var _pawns: Dictionary = {}
var _scene: PackedScene
var _own_slot: int = SlotTable.NO_SLOT
var _interpolator := SnapshotInterpolator.new()
var _clock := RenderClock.new()


func _ready() -> void:
	_scene = load(PAWN_REMOTE) as PackedScene
	Net.snapshot_received.connect(apply_snapshot)


## Ignore this slot: it is us. Set from `NET-S2C-WELCOME`, which carries the
## client's own wire identity.
func set_own_slot(slot: int) -> void:
	_own_slot = slot


## Record what the snapshot said, create the slots that are new, and free the
## ones it did not mention. **Nothing moves here** — moving is the clock's job.
##
## **ABSENCE IS THE SIGNAL FOR LEAVING.** There is no "player left" record in the
## snapshot, deliberately: a client that missed one reliable message would keep a
## ghost forever, whereas a client that misses one snapshot recovers on the next.
func apply_snapshot(snapshot: Snapshot) -> void:
	var server_time := float(snapshot.server_tick) / Tuning.net.server_tick
	_clock.observe(server_time)
	var seen: Dictionary = {}
	for record: Array in snapshot.remote_pawns:
		var slot: int = record[0]
		if slot == _own_slot or slot == SlotTable.NO_SLOT:
			continue
		seen[slot] = true
		if not _pawns.has(slot):
			_spawn(slot)
		_interpolator.push(slot, server_time, record[1] as Vector3, record[2] as float)
	_free_unseen(seen)


## Draw every remote pawn where it was `TUN-NET-INTERP-BUFFER` ago.
##
## Between snapshots this is the only thing moving them, which is the difference
## between a player walking and a player teleporting 30 times a second.
func _physics_process(delta: float) -> void:
	_clock.advance(delta)
	if not _clock.started():
		return
	var at := _clock.render_time()
	for slot: int in _pawns:
		var placed: Array = _interpolator.sample(slot, at)
		if placed.is_empty():
			continue
		var pawn := _pawns[slot] as Node3D
		pawn.global_position = placed[0] as Vector3
		pawn.rotation.y = placed[1] as float


func _spawn(slot: int) -> void:
	if _scene == null:
		return
	var pawn := _scene.instantiate() as Node3D
	pawn.name = "PawnRemote_%d" % slot
	add_child(pawn)
	_pawns[slot] = pawn
	Log.info("remote pawn appeared in slot %d" % slot, &"net")
	remote_appeared.emit(slot)


func _free_unseen(seen: Dictionary) -> void:
	for slot: int in _pawns.keys():
		if seen.has(slot):
			continue
		(_pawns[slot] as Node).queue_free()
		_pawns.erase(slot)
		_interpolator.forget(slot)
		Log.info("remote pawn vanished from slot %d" % slot, &"net")
		remote_vanished.emit(slot)


func count() -> int:
	return _pawns.size()


func has_slot(slot: int) -> bool:
	return _pawns.has(slot)
