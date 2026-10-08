## **HIDING THE DEBUG MAP PUTS THE STREET'S OWN MATERIAL BACK.** Found 2026-10-09.
##
## The overlay tints every street floor while shown and, while hidden, used to set
## each floor's override to `null`, on a docstring's word that the generator gave
## the floors none. It gives them `MAT-GREY-FLOOR`, and the overlay starts hidden,
## so every debug build drew every street in Godot's default white — and the blend
## net (US-0107) on it could not be seen. A red floor drew white too.
extends GutTest

var _floor: MeshInstance3D
var _own: StandardMaterial3D


func before_each() -> void:
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child_autofree(geometry)
	var body := Node3D.new()
	body.name = str(VetraioLayout.FLOORS[0][0])
	geometry.add_child(body)
	_floor = MeshInstance3D.new()
	_floor.name = "Mesh"
	_own = StandardMaterial3D.new()
	_own.resource_name = "MAT-GREY-FLOOR"
	_floor.material_override = _own
	body.add_child(_floor)


func test_the_floor_keeps_its_own_material_once_the_map_is_hidden() -> void:
	var overlay: Node = DistrictMap.attach(self, null)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_ne(_floor.material_override, _own, "PREMISE: the map never tinted the floor")
	overlay.call(&"set_overlay_shown", false)
	assert_eq(_floor.material_override, _own, "the street was left with no material: white")
	overlay.queue_free()
