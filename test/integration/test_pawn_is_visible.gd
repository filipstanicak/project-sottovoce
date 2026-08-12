## There is a body to look at, and it is the size of the thing that collides.
## ART_BIBLE §6, GDD-02 §4.1, US-0091.
##
## **THE CAMERA FRAMED NOTHING FOR THREE STORIES.** `PersonaVisuals` was an empty
## `Node3D` in both pawn scenes, so US-0021's spring arm, US-0022's FOV ladder and
## US-0023's crowd-scan were all built, tested and merged around a pawn that did
## not render. Every one of those suites passed: they assert positions, distances
## and lens values, and a camera 2.6 m behind an invisible capsule satisfies all
## of them. **Nothing anywhere asked whether there was anything to see.**
##
## Which is the same defect family as the inverted pitch in #48 and the
## world-space stick in #51: the arithmetic was right and the *result* was not the
## one the design describes. GDD-02 §4.1 puts this game in third person for one
## reason — the player must be able to judge their own silhouette — and a
## silhouette is exactly what was missing.
##
## Headless has no renderer, so none of this proves a pixel was lit. What it
## proves is that the nodes exist, carry meshes, and occupy the space the collider
## occupies. The pixels were checked by looking at the game.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"
const LOCAL_PAWN := "res://scenes/pawn/pawn_local.tscn"
const REMOTE_PAWN := "res://scenes/pawn/pawn_remote.tscn"

var _root: Node
var _pawn: Node3D


func before_each() -> void:
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_pawn = _root.get_node("World/PawnLocal")
	await get_tree().physics_frame


func _visuals() -> Node3D:
	return _pawn.get_node("PersonaVisuals") as Node3D


func _meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in _visuals().get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
	return out


## The visuals' extent in the PAWN's own space, which is where "the origin is the
## feet" is a claim that can be checked.
func _bounds() -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in _meshes():
		var local := mesh.mesh.get_aabb()
		local.position += mesh.position
		box = local if first else box.merge(local)
		first = false
	return box


func _collider() -> CapsuleShape3D:
	var node := _pawn.get_node("CollisionShape3D") as CollisionShape3D
	return node.shape as CapsuleShape3D


# ------------------------------------------------------------ there is a body --


func test_the_pawn_has_meshes_at_all() -> void:
	assert_gt(_meshes().size(), 0, "PersonaVisuals is empty — the camera is framing nothing")


func test_every_mesh_carries_a_material() -> void:
	# An unlit default-white capsule would be visible and would also be the one
	# thing ART_BIBLE §3 forbids: a value that is not in the desaturated range.
	for mesh: MeshInstance3D in _meshes():
		assert_not_null(mesh.mesh.material, "%s has no material" % mesh.name)


# ------------------------------------------- it is the size of what collides --


func test_the_body_is_as_tall_as_the_collider() -> void:
	# **NOT "the body is tall".** A visual that is not the size of the thing that
	# collides teaches the player a silhouette and then stops them with geometry
	# they cannot see.
	assert_almost_eq(_bounds().size.y, _collider().height, 0.05, "the body is not the collider")


func test_the_body_stands_on_the_origin_rather_than_straddling_it() -> void:
	# The pawn's origin is its FEET — `pawn_local.tscn` raises the collision shape
	# by half the capsule for that reason. A mesh centred on the origin instead is
	# drawn buried to the waist, which is precisely how US-0017's spawn bug looked.
	assert_almost_eq(_bounds().position.y, 0.0, 0.05, "the body is sunk into the ground")


func test_the_body_is_no_wider_than_the_collider() -> void:
	var width := maxf(_bounds().size.x, _bounds().size.z)
	assert_lt(width, _collider().radius * 3.0, "the body is wider than the thing that collides")


# ----------------------------------------------------------- it has a facing --


func test_something_marks_the_front() -> void:
	# A capsule is rotationally symmetric. Without a marker the player cannot read
	# their own facing — and facing is what the camera, the kill cone and every
	# traversal probe are measured against.
	var front := 0
	for mesh: MeshInstance3D in _meshes():
		if mesh.position.z > 0.0:
			front += 1
	assert_gt(front, 0, "nothing on the body distinguishes front from back")


func test_the_front_is_the_direction_the_probes_call_forward() -> void:
	# +Z, agreeing with `ProbeLayout.forward(0)`. A marker on the back would make
	# the pawn read as facing away from where it is about to vault.
	var forward := ProbeLayout.forward(0.0)
	for mesh: MeshInstance3D in _meshes():
		if mesh.position.z != 0.0:
			assert_gt(mesh.position.z * forward.z, 0.0, "%s marks the wrong side" % mesh.name)


# ------------------------------------------------------------ what it is not --


func test_the_visuals_do_not_collide() -> void:
	# Presentation may never change the world. A collider here would push the
	# pawn, block the traversal probes, and give the camera something new to pull
	# in from.
	for child: Node in _visuals().get_children():
		assert_false(child is CollisionObject3D, "%s collides" % child.name)
		assert_false(child is CollisionShape3D, "%s collides" % child.name)


func test_the_remote_pawn_wears_the_same_body() -> void:
	# **CLONE PARITY, AND IT STARTS HERE.** A remote pawn that looked different
	# from a local one would be a discriminator in a game built on players being
	# indistinguishable from each other and from the crowd — ART_BIBLE §2. The
	# same script, not a copy of it.
	var local := (load(LOCAL_PAWN) as PackedScene).instantiate()
	var remote := (load(REMOTE_PAWN) as PackedScene).instantiate()
	var local_script: Script = local.get_node("PersonaVisuals").get_script()
	var remote_script: Script = remote.get_node("PersonaVisuals").get_script()
	assert_not_null(remote_script, "the remote pawn has no body at all")
	assert_eq(remote_script, local_script, "remote and local pawns wear different bodies")
	local.free()
	remote.free()
