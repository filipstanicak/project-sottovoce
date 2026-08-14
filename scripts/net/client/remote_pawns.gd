## **THE OTHER PLAYERS, AS THE SERVER LAST DESCRIBED THEM.** TDD-01 §3.2.
## CLIENT ONLY.
##
## One `pawn_remote.tscn` per slot in the snapshot, created when a slot first
## appears and freed when it stops appearing. No state machine, no navigation
## agent, no collision — TDD-06 §1 rule 2: a remote pawn that simulated would
## produce a second, wrong answer that disagrees with the server's.
##
## **THIS SNAPS; IT DOES NOT INTERPOLATE.** `SnapshotInterpolator` is US-0034 and
## it is the story that makes this look right — 30 Hz of teleporting is exactly
## what the 100 ms interpolation buffer exists to hide. Snapping first is
## deliberate: it makes the wire visible before the thing that smooths it, so a
## replication bug cannot hide inside an interpolator.
class_name RemotePawns
extends Node3D

## A slot appeared or vanished. Past tense; the node already exists or is gone.
signal remote_appeared(slot: int)
signal remote_vanished(slot: int)

const PAWN_REMOTE := "res://scenes/pawn/pawn_remote.tscn"

var _pawns: Dictionary = {}
var _scene: PackedScene
var _own_slot: int = SlotTable.NO_SLOT


func _ready() -> void:
	_scene = load(PAWN_REMOTE) as PackedScene
	Net.snapshot_received.connect(apply_snapshot)


## Ignore this slot: it is us. Set from `NET-S2C-WELCOME`, which carries the
## client's own wire identity.
func set_own_slot(slot: int) -> void:
	_own_slot = slot


## Move every slot the snapshot named, create the ones that are new, and free the
## ones it did not mention.
##
## **ABSENCE IS THE SIGNAL FOR LEAVING.** There is no "player left" record in the
## snapshot, deliberately: a client that missed one reliable message would keep a
## ghost forever, whereas a client that misses one snapshot recovers on the next.
func apply_snapshot(snapshot: Snapshot) -> void:
	var seen: Dictionary = {}
	for record: Array in snapshot.remote_pawns:
		var slot: int = record[0]
		if slot == _own_slot or slot == SlotTable.NO_SLOT:
			continue
		seen[slot] = true
		_place(slot, record[1] as Vector3, record[2] as float)
	_free_unseen(seen)


func _place(slot: int, position: Vector3, yaw: float) -> void:
	if not _pawns.has(slot):
		_spawn(slot)
	var pawn := _pawns.get(slot) as Node3D
	if pawn == null:
		return
	pawn.global_position = position
	pawn.rotation.y = yaw


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
		Log.info("remote pawn vanished from slot %d" % slot, &"net")
		remote_vanished.emit(slot)


func count() -> int:
	return _pawns.size()


func has_slot(slot: int) -> bool:
	return _pawns.has(slot)
