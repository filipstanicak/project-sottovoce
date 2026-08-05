## Builds throwaway `WORLD` geometry for the traversal integration tests.
##
## Not a test — a fixture. `run_gut.sh` counts `test_*.gd`, so this file is
## invisible to the script-count check and cannot dilute it.
##
## The heights it offers are the ones the level-design contract (GDD-02 §7.4)
## builds at, because those are the cases MAP-VETRAIO will actually present:
## 0.9 m vaults, 1.8 m mantles, 4 m climbs, a 2 m gap. Nothing here invents a
## measurement the map does not use.
class_name TraversalWorld
extends RefCounted

## Facing +Z, matching `ProbeLayout.forward(0)`. Obstacles go in front at +Z.
const FACING := 0.0

var root: Node3D

var _slab: StaticBody3D


func _init(parent: Node) -> void:
	root = Node3D.new()
	parent.add_child(root)
	ground()


## A 40 x 40 slab whose TOP surface is y = 0, so a pawn's feet sit at the origin.
func ground() -> void:
	_slab = box(Vector3(40.0, 2.0, 40.0), Vector3(0.0, -1.0, 0.0))


## A static `WORLD` body. `size` is full extents; `centre` is its middle.
func box(size: Vector3, centre: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	root.add_child(body)
	body.global_position = centre
	return body


## A wall of `height`, standing on the ground, `ahead` metres in front.
func obstacle(height: float, ahead: float, thickness: float = 0.4) -> void:
	box(Vector3(6.0, height, thickness), Vector3(0.0, height * 0.5, ahead))


## Replace the slab with one stopping at `near_edge`, and put its far side at
## `far_edge`, `far_drop` metres down. A `far_edge` beyond reach leaves a sheer
## drop with nothing to land on.
func open_gap(near_edge: float, far_edge: float, far_drop: float = 0.0) -> void:
	_slab.queue_free()
	root.remove_child(_slab)
	_slab = null
	box(Vector3(40.0, 2.0, 40.0), Vector3(0.0, -1.0, near_edge - 20.0))
	if far_edge < 100.0:
		box(Vector3(40.0, 2.0, 40.0), Vector3(0.0, -1.0 - far_drop, far_edge + 20.0))


## A grabbable top at chest height, `lateral` metres to the pawn's RIGHT.
##
## NARROW — 0.4 m — so the centre probe misses it entirely. A block wide enough
## to sit under the pawn's nose would be found at lateral 0, and the offset the
## ledge tests exist to check would read as zero whichever side it was on.
func ledge_block(lateral: float, height: float = 1.35) -> void:
	var x := ProbeLayout.right(FACING).x * lateral
	box(Vector3(0.4, height, 0.8), Vector3(x, height * 0.5, 0.8))


## A `PawnContext` at `feet`, facing `yaw`.
static func context(feet: Vector3, yaw: float, grounded: bool) -> PawnContext:
	var ctx := PawnContext.new()
	ctx.position = feet
	ctx.yaw = yaw
	ctx.grounded = grounded
	return ctx
