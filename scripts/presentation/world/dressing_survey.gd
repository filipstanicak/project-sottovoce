## **WHAT THE GREYBOX IS MADE OF, READ BACK FROM THE SCENE.** ADR-0026. CLIENT ONLY.
##
## The art pass dresses whatever map was loaded, so it reads the generated scene
## rather than a layout table: every solid is a `StaticBody3D` holding one box,
## named by the generator and painted with one of the greybox materials. Those
## two facts are the whole vocabulary, and they are the same on `MAP-VETRAIO` and
## on the sandbox, which the release build does not even ship.
##
## **IT READS AND NEVER WRITES.** ART_BIBLE §7.1: art may not change a traversable
## height, a navmesh boundary or a sightline. Nothing here or downstream moves,
## resizes or adds a collider; `test_the_dressing_changes_no_geometry.gd`.
class_name DressingSurvey
extends RefCounted

enum Role { FLOOR, BLOCK, STALL, PARAPET, PROP, BENCH }


## One greybox solid.
class Part:
	var name := ""
	var role := Role.BLOCK
	## A facade a pawn can climb: `MAT-CLIMB` in the greybox.
	var climbable := false
	var centre := Vector3.ZERO
	var size := Vector3.ZERO
	var mesh: MeshInstance3D = null

	func top() -> float:
		return centre.y + size.y * 0.5

	func bottom() -> float:
		return centre.y - size.y * 0.5

	## The footprint, x and z.
	func rect() -> Rect2:
		return Rect2(centre.x - size.x * 0.5, centre.z - size.z * 0.5, size.x, size.z)


var parts: Array[Part] = []


func _init(map_root: Node) -> void:
	var geometry := map_root.get_node_or_null("Geometry") if map_root != null else null
	if geometry == null:
		return
	for child: Node in geometry.get_children():
		var part := _read(child)
		if part != null:
			parts.append(part)


func _read(node: Node) -> Part:
	var body := node as StaticBody3D
	if body == null:
		return null
	var collision := body.get_node_or_null("Collision") as CollisionShape3D
	var shape := collision.shape as BoxShape3D if collision != null else null
	if shape == null:
		return null
	var part := Part.new()
	part.name = String(body.name)
	part.centre = body.position
	part.size = shape.size
	part.mesh = body.get_node_or_null("Mesh") as MeshInstance3D
	var paint := ""
	if part.mesh != null and part.mesh.material_override != null:
		paint = part.mesh.material_override.resource_name
	part.climbable = paint == "MAT-CLIMB"
	part.role = _role(part.name, paint)
	return part


static func _role(name: String, paint: String) -> Role:
	if paint == "MAT-GREY-FLOOR":
		return Role.FLOOR
	if name.begins_with("Stall"):
		return Role.STALL
	if name.begins_with("Prop_"):
		return Role.PROP
	if name.begins_with("Bench"):
		return Role.BENCH
	if paint == "MAT-VAULT":
		return Role.PARAPET
	return Role.BLOCK


func of(role: Role) -> Array[Part]:
	var out: Array[Part] = []
	for part: Part in parts:
		if part.role == role:
			out.append(part)
	return out


## Whether a street-level floor lies under `at` (x, z).
func ground_at(at: Vector2) -> bool:
	for part: Part in parts:
		if part.role == Role.FLOOR and part.top() < 1.0 and part.rect().has_point(at):
			return true
	return false


## The top of the tallest block standing over `at`, other than `except`; 0 when
## none does. A facade is hidden up to that height by whatever stands against it.
func block_top_at(at: Vector2, except: Part) -> float:
	var highest := 0.0
	for part: Part in parts:
		if part != except and part.role == Role.BLOCK and part.rect().has_point(at):
			highest = maxf(highest, part.top())
	return highest


## The district's extent over x and z, every solid included.
func bounds() -> Rect2:
	if parts.is_empty():
		return Rect2()
	var all := parts[0].rect()
	for part: Part in parts:
		all = all.merge(part.rect())
	return all
