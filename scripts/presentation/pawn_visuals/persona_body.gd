## **THE FOUR GREYBOX PERSONAS.** ART_BIBLE §6.1, `SCOPE_FENCE` IN #3, US-0046.
## CLIENT ONLY.
##
## **PROCEDURAL, BECAUSE NO MODEL MAY EVER ENTER THIS REPOSITORY.** IP_GUARDRAILS
## §4 and ASM-0029: primitives only, no downloaded meshes, not for reference and
## not on a branch. Everything here is `CapsuleMesh`, `SphereMesh`, `BoxMesh` and
## `CylinderMesh` built at runtime, so there is no asset to licence and nothing to
## attribute in `ASSET_LICENSES.md`.
##
## **EACH ROW OF §6.1 IS A SILHOUETTE *CLAIM*, NOT A DECORATION.** The claim is
## that the four are tellable apart at 40 m in solid black (§1.2), and it is the
## claim the entire anonymity model rests on from the other side: a hunter must be
## able to say "that is a Lucerna" without being able to say "that is a *player*".
## If the greybox fails the test, no amount of art fixes it; if it passes, art is
## polish rather than rescue.
##
## **WHY THIS IS NOT `GreyboxBody`.** That one is deliberately generic — a body
## the size of the collider with enough shape to read a facing — and it says so,
## because building a persona there would have asserted an untested claim. This is
## the persona, and it inherits the two properties that made the generic one
## correct: it is measured from the collider, and its head cannot poke out of it.
##
## **NO PER-INSTANCE VARIATION, EVER.** No tint, no accessory shuffle, no scale
## jitter — GDD-03 §6.3 rule 6. Any variation the player cannot also have is a
## discriminator; any variation they *can* have is a cosmetic system, which
## `SCOPE_FENCE` OUT #3 rules out for exactly this reason. `randf` does not appear
## in this file and `test_no_clone_variation.gd` keeps it that way.
class_name PersonaBody
extends Node3D

## ART_BIBLE §3: everything that is not persona identity, suspicion tint or an
## ability tell lives in this desaturated warm-neutral range.
const BODY_COLOUR := Color(0.55, 0.52, 0.50)
const MARKER_COLOUR := Color(0.34, 0.32, 0.31)

## Fallback capsule, matching the pawn's. If these are ever the values in play,
## something upstream is already wrong.
const FALLBACK_RADIUS := 0.35
const FALLBACK_HEIGHT := 1.8

const HEAD_FRACTION := 0.62
const MARKER_SIZE := Vector3(0.30, 0.16, 0.12)

## Which persona to build. Set before the node enters the tree.
@export var persona: StringName = Ids.PERSONA_VETRAIO

var _radius: float = FALLBACK_RADIUS
var _collider_height: float = FALLBACK_HEIGHT


func _ready() -> void:
	var capsule := _capsule()
	_radius = capsule.x
	_collider_height = capsule.y
	_build()


## **THE COLLIDER IS ONE CAPSULE FOR ALL FOUR, AND THE SILHOUETTES DIFFER.** Both
## halves are the same anonymity rule from opposite ends: a clone whose collider
## differed from a player's would be findable by walking into it, and a persona
## whose silhouette matched another would be one fewer thing a hunter can read.
## So the drawn height comes from `PersonaData` and the collision does not.
func _capsule() -> Vector2:
	var body := get_parent()
	if body != null:
		var node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var shape := null if node == null else node.shape as CapsuleShape3D
		if shape != null:
			return Vector2(shape.radius, shape.height)
	return Vector2(FALLBACK_RADIUS, FALLBACK_HEIGHT)


func _build() -> void:
	match persona:
		Ids.PERSONA_CANTATRICE:
			_cantatrice()
		Ids.PERSONA_LUCERNA:
			_lucerna()
		Ids.PERSONA_PESATORE:
			_pesatore()
		_:
			_vetraio()
	_facing_marker()


## **Vetraio** — capsule, 1.68 m, ×1.4 shoulder scale, box on chest. The short
## broad one: `LOW_BROAD`.
func _vetraio() -> void:
	_torso(1.68, 1.0)
	_head(1.68)
	_shoulders(1.68, 1.4)
	_attach(
		"Chest",
		_box(Vector3(_radius * 0.9, 0.22, 0.18)),
		Vector3(0.0, 1.68 * 0.66, _radius * 0.7),
		MARKER_COLOUR
	)


## **Cantatrice** — capsule + cone skirt, 1.72 m, sphere on head. The one that
## widens toward the ground: `FLOOR_TRIANGLE`.
func _cantatrice() -> void:
	_torso(1.72, 1.0)
	_head(1.72)
	var skirt := CylinderMesh.new()
	skirt.top_radius = _radius * 0.9
	# **1.5x, NOT 2x.** A skirt that overhangs the collider too far is the
	# silhouette lying about the thing it stands for: a hunter reads a shape they
	# cannot walk through and aims at a gap that is really open. 1.5 still reads as
	# a floor triangle at 40 m and keeps the lie under 20 cm a side.
	skirt.bottom_radius = _radius * 1.5
	skirt.height = 0.85
	_attach("Skirt", skirt, Vector3(0.0, 0.425, 0.0), BODY_COLOUR)
	var crown := SphereMesh.new()
	crown.radius = _radius * 0.34
	crown.height = crown.radius * 2.0
	_attach("Crown", crown, Vector3(0.0, 1.72 + crown.radius * 0.4, 0.0), MARKER_COLOUR)


## **Lucerna** — capsule, 1.89 m, ×0.8 width, cylinder pole 0.9 m above the head.
## The tall thin one, and **the only silhouette that breaks the head line**:
## `TALL_THIN`.
func _lucerna() -> void:
	_torso(1.89, 0.8)
	_head(1.89)
	# **THE POLE IS CARRIED, NOT FLOATING.** §6.1 says "0.9 m above head", which is
	# where its *top* goes; a cylinder only 0.9 m long put the whole thing in the
	# air beside the figure, and the first render of these four showed a stick
	# hovering next to a capsule. It runs from hand height instead, so the
	# silhouette reads as somebody carrying something — which is what makes
	# `TALL_THIN` break the head line rather than just being tall.
	var hand := 0.95
	var top := 1.89 + 0.9
	var pole := CylinderMesh.new()
	pole.top_radius = 0.035
	pole.bottom_radius = 0.035
	pole.height = top - hand
	_attach("Pole", pole, Vector3(_radius * 0.9, hand + pole.height * 0.5, 0.0), MARKER_COLOUR)


## **Pesatore** — capsule, 1.75 m, uniform, box under the arm. The unremarkable
## one, which is its own silhouette: `ROUND_MID`.
func _pesatore() -> void:
	_torso(1.75, 1.0)
	_head(1.75)
	_attach(
		"Ledger",
		_box(Vector3(0.26, 0.20, 0.34)),
		Vector3(_radius * 1.1, 1.75 * 0.52, 0.0),
		MARKER_COLOUR
	)


## The body capsule, drawn at the persona's own height and width.
func _torso(height: float, width: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = _radius * width
	mesh.height = height
	_attach("Body", mesh, Vector3(0.0, height * 0.5, 0.0), BODY_COLOUR)


## **THE HEAD'S CROWN SITS AT THE CAPSULE'S TOP, NOT ON IT.** `GreyboxBody`
## learned this the expensive way: a head placed *on* the capsule put its crown
## 0.22 m above the shape that collides, so the figure walked its head through
## gaps its body fit — the silhouette lying about the thing it stands for.
func _head(height: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = _radius * HEAD_FRACTION
	mesh.height = mesh.radius * 2.0
	_attach("Head", mesh, Vector3(0.0, height - mesh.radius, 0.0), BODY_COLOUR)


func _shoulders(height: float, scale: float) -> void:
	var mesh := _box(Vector3(_radius * 2.0 * scale, 0.20, _radius * 1.2))
	_attach("Shoulders", mesh, Vector3(0.0, height * 0.80, 0.0), BODY_COLOUR)


## **THE ONE PIECE THAT IS NOT SILHOUETTE.** A capsule is rotationally symmetric,
## so a figure built only from capsules gives no way to read facing — and facing
## is what the camera, the kill cone and every traversal probe are measured
## against. `+Z` is forward, agreeing with `ProbeLayout.forward(0)`.
func _facing_marker() -> void:
	var mesh := _box(MARKER_SIZE)
	var forward := _radius + MARKER_SIZE.z * 0.5
	_attach("Facing", mesh, Vector3(0.0, _collider_height * 0.72, forward), MARKER_COLOUR)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


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
