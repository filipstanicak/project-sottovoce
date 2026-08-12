## The placeholder body. ART_BIBLE §6.1 and §6.2.
##
## **THE CAMERA HAD NOTHING TO FRAME.** GDD-02 §4.1 puts this game in third
## person for one reason: judging *how do I look right now* is a core skill when
## anonymity is the resource, and it is impossible from inside your own head. A
## spring arm 2.6 m behind an invisible pawn is a first-person camera with extra
## steps — the whole justification for the rig was missing until this existed.
##
## **PROCEDURAL, BECAUSE NO MODEL MAY EVER ENTER THIS REPOSITORY.** IP_GUARDRAILS
## §4 and ASM-0029: primitives only, no downloaded meshes, not for reference and
## not on a branch. Everything below is built from `CapsuleMesh`, `SphereMesh` and
## `BoxMesh` at runtime, so there is no asset to licence and nothing to attribute.
##
## **THIS IS NOT A PERSONA.** ART_BIBLE §6.1 gives four greybox constructions —
## Vetraio's shoulder scale, Cantatrice's cone skirt, Lucerna's pole, Pesatore's
## box — and each is a *silhouette claim* that has to pass the §1.2 test at 40 m
## in solid black. Building one of them here would assert a claim nobody has
## tested and would quietly start `PERSONA-*` work that belongs to US-0039 with
## its clone-parity rules. What this is instead is deliberately generic: a body
## the size of the collider, with enough shape to read a facing.
class_name GreyboxBody
extends Node3D

## Desaturated warm-neutral, ART_BIBLE §3: everything that is not persona
## identity, suspicion tint or an ability tell lives in this range. Plaster, a
## shade off the `MAT-GREY-WALL` the district is built from, so a pawn standing
## against a façade is still a separate shape.
const BODY_COLOUR := Color(0.55, 0.52, 0.50)

## The chest marker, darker rather than a different hue. ART_BIBLE §3.1's
## "value over hue": readability comes from light/dark contrast, and the four
## saturated identity hues are reserved for a system that does not exist yet.
const MARKER_COLOUR := Color(0.34, 0.32, 0.31)

## Fallbacks, used only when there is no `CollisionShape3D` to measure. They
## match `pawn_local.tscn`'s capsule, and if they are ever the values in play
## something upstream is already wrong.
const FALLBACK_RADIUS := 0.35
const FALLBACK_HEIGHT := 1.8

## Head size and chest-marker size as fractions of the body, so one capsule
## change moves the whole figure and nothing has to be re-measured by hand.
const HEAD_FRACTION := 0.62
const MARKER_SIZE := Vector3(0.30, 0.16, 0.12)


func _ready() -> void:
	var shape := _capsule()
	var radius: float = shape.x
	var height: float = shape.y
	_add_capsule(radius, height)
	_add_head(radius, height)
	_add_facing_marker(radius, height)


## The collider's radius and height, **read from the sibling `CollisionShape3D`
## rather than declared here.** A visual that is not the size of the thing it
## draws is worse than no visual: the player learns a silhouette, aims at gaps
## with it, and is stopped by geometry they cannot see. Measuring the collider
## makes the two impossible to drift apart.
func _capsule() -> Vector2:
	var owner_body := get_parent()
	if owner_body != null:
		var node := owner_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var capsule := null if node == null else node.shape as CapsuleShape3D
		if capsule != null:
			return Vector2(capsule.radius, capsule.height)
	return Vector2(FALLBACK_RADIUS, FALLBACK_HEIGHT)


## The body, sitting exactly where the collider sits.
##
## **THE PAWN'S ORIGIN IS ITS FEET** — `pawn_local.tscn` raises the collision
## shape by half the capsule height for that reason, because spawn points and
## every traversal probe are measured from the ground. The mesh has to be raised
## by the same half or the body is drawn buried to the waist.
func _add_capsule(radius: float, height: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_attach("Body", mesh, Vector3(0.0, height * 0.5, 0.0), BODY_COLOUR)


## **THE HEAD MUST NOT POKE OUT OF THE COLLIDER.** Sitting it *on* the capsule
## put its crown 0.22 m above the shape that collides, so the pawn would have
## walked its head through a gap its body fit — the silhouette lying about the
## thing it stands for, which is the one job this body has. Its top is the
## capsule's top instead.
func _add_head(radius: float, height: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius * HEAD_FRACTION
	mesh.height = mesh.radius * 2.0
	_attach("Head", mesh, Vector3(0.0, height - mesh.radius, 0.0), BODY_COLOUR)


## **THE ONE PIECE THAT IS NOT DECORATION.** A capsule is rotationally symmetric,
## so a pawn built only from capsules gives the player no way to read which way
## they are facing — and facing is what the camera, the kill cone and every
## traversal probe are all measured against.
##
## `+Z` is forward: `ProbeLayout.forward(0)` is `+Z`, and the camera agrees.
func _add_facing_marker(radius: float, height: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = MARKER_SIZE
	var forward := radius + MARKER_SIZE.z * 0.5
	_attach("Facing", mesh, Vector3(0.0, height * 0.72, forward), MARKER_COLOUR)


func _attach(node_name: String, mesh: Mesh, offset: Vector3, colour: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = offset
	add_child(instance)
