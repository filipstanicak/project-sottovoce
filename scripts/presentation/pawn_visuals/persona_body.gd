## **EVERY FIGURE IN THE DISTRICT.** ART_BIBLE §1 and §6.1, US-0046, US-0109.
## CLIENT ONLY.
##
## The local player, every other player and every civilian is one of these: a
## skeleton (`FigureRig`) in a persona's proportions (`FigureShape`), dressed by
## `FigureTailor` and `FigureGarments`, moved by `FigureAnimator`. It was a capsule
## with a box on it until 2026-11-16, and it glided.
##
## **PROCEDURAL, BECAUSE NO MODEL MAY EVER ENTER THIS REPOSITORY.** IP_GUARDRAILS
## §4 and ADR-0026: every part is a capsule, a ball, a box or a drum built at
## runtime, so there is no asset to licence and nothing to attribute.
##
## **EACH PERSONA IS A SILHOUETTE *CLAIM*, NOT A DECORATION**: tellable apart at
## 40 m in solid black (§1.2). A hunter must be able to say "that is a Lucerna"
## without being able to say "that is a *player*".
##
## **THE CLOTHING WEARS THE IDENTITY HUE, AND NOTHING ELSE DOES.** Every Lucerna,
## player or clone, is the same yellow: a colour is a persona property, never an
## instance one (§3, GDD-03 §6.3 rule 6).
##
## **NO PER-INSTANCE VARIATION, EVER** — no tint, no accessory shuffle, no scale
## jitter. Any variation the player cannot also have is a discriminator; any they
## *can* have is a cosmetic system, which `SCOPE_FENCE` OUT #3 rules out for
## exactly this reason. `test_no_clone_variation.gd` keeps randomness out of every
## file that draws a figure.
##
## **AND IT MOVES BY WHAT IT DOES, NEVER BY WHAT IT IS.** The pose is read from the
## body's own movement, the place it stands and the act it was told — the same
## three for a player and a clone (`FigureAnimator`). `act()` is the one thing an
## owner tells it, and every act is one ANIMATION_SPEC §1 puts past the anonymity
## boundary.
class_name PersonaBody
extends Node3D

## ART_BIBLE §3: the undressed figure's two neutrals, and the props' value.
const BODY_COLOUR := Color(0.55, 0.52, 0.50)
const MARKER_COLOUR := Color(0.34, 0.32, 0.31)

## Fallback capsule, matching the pawn's. If these are ever the values in play,
## something upstream is already wrong.
const FALLBACK_RADIUS := 0.35
const FALLBACK_HEIGHT := 1.8

## How far a greyed part moves from its colour toward `GREY`: "slightly greyed",
## the hue still there to read the persona by.
const GREY_MIX := 0.5
const GREY := Color(0.72, 0.72, 0.72)
## A body moved faster than this in one step was placed, not walked: a spawn.
const TELEPORT_SPEED := 14.0
## How fast a figure turns to face its bench or counter, per second.
const TURN_EASE := 8.0

## Which figure to build: a persona, a filler archetype, or `&""` for the
## undressed one. Set before the node enters the tree, or change it afterwards
## through `dress()`.
@export var persona: StringName = &""

## The palette the clothing is coloured from — **the same instance the HUD draws
## the contract portrait with**, handed over by `Wardrobe`, so a colourblind palette
## moves the figures and the portrait together. Null means the default palette.
var palette: Palette = null

var _collider_height: float = FALLBACK_HEIGHT
var _greyed := false
var _rig: FigureRig = null
var _animator := FigureAnimator.new()
## What moves when this figure moves: the pawn it is the picture of, or itself.
var _anchor: Node3D = null
var _was := Vector3.ZERO
var _seen := false


func _ready() -> void:
	_collider_height = _capsule().y
	var parent := get_parent() as Node3D
	_anchor = self if parent == null or parent is NpcView else parent
	_build()
	# A bot and a booted test client have no screen to animate a crowd for.
	set_physics_process(DisplayGate.draws())


## **THE COLLIDER IS ONE CAPSULE FOR ALL FIGURES, AND THE SILHOUETTES DIFFER.** A
## clone whose collider differed from a player's would be findable by walking into
## it, so the drawn height comes from `FigureShape` and the collision does not.
func _capsule() -> Vector2:
	var body := get_parent()
	if body != null:
		var node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var shape := null if node == null else node.shape as CapsuleShape3D
		if shape != null:
			return Vector2(shape.radius, shape.height)
	return Vector2(FALLBACK_RADIUS, FALLBACK_HEIGHT)


## **Re-dress in place.** False when there was nothing to change, so a caller that
## re-dresses every body on every state change costs nothing for the unchanged ones.
func dress(to: StringName) -> bool:
	if to == persona and (get_child_count() > 0 or not is_inside_tree()):
		return false
	persona = to
	if not is_inside_tree():
		return true
	# **FREED NOW, NOT QUEUED.** A queued part is already out of the tree and not yet
	# gone, and a district re-dressed at once left ~150 of them orphaned for a frame.
	for child: Node in get_children():
		child.free()
	_build()
	return true


## **GREYED ON ONE SCREEN ONLY: THE BLENDED PLAYER'S, FOR THEIR OWN GROUP** (US-0107).
## The one per-instance difference a body may carry, and rule 6 still holds: it is
## drawn for the blender alone, over figures they already know they stand with.
## `BlendCues` is its only caller.
func set_greyed(on: bool) -> void:
	if on == _greyed:
		return
	_greyed = on
	_paint()


func is_greyed() -> bool:
	return _greyed


## Each part in its own colour, or that colour greyed. Materials are shared by
## every figure, so a part is repainted by being handed another one.
func _paint() -> void:
	for part: MeshInstance3D in parts():
		var base: Color = part.get_meta(&"base", BODY_COLOUR)
		part.material_override = FigureParts.paint(base.lerp(GREY, GREY_MIX) if _greyed else base)


## Whether this body is drawn as a persona — rather than as a filler or undressed.
func is_dressed() -> bool:
	return CrowdRoster.PLAYABLE.has(persona)


## Whether this body is one of the five figures no player can be.
func is_filler() -> bool:
	return CrowdRoster.ARCHETYPES.has(persona)


## The clothing's colour for what is being worn.
func cloth() -> Color:
	if is_filler():
		return FigureTrades.cloth_of(persona)
	if not is_dressed():
		return BODY_COLOUR
	return (palette if palette != null else Palette.fallback()).for_persona(persona)


func _build() -> void:
	var shown := persona if is_dressed() or is_filler() else &""
	var shape := FigureShape.of(shown, _collider_height)
	_rig = FigureRig.new(self, shape)
	var paint := FigureTailor.paint_for(shown, cloth())
	FigureTailor.clothe(_rig, paint)
	FigureGarments.dress(_rig, paint)
	_rig.apply(FigurePose.new())
	# A body re-dressed while its player is blended stays greyed.
	if _greyed:
		_paint()


## Every drawn part of the figure, wherever on the skeleton it hangs.
func parts() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


## The part called `part_name`, or null. A figure has one of each named piece
## except its paired limbs, of which this is the left.
func part(part_name: String) -> MeshInstance3D:
	var found := find_children(part_name, "MeshInstance3D", true, false)
	return null if found.is_empty() else found[0] as MeshInstance3D


## The box `piece` fills, in this body's own space: where it is, not where its
## joint is. The body has to be in the tree.
func box_of(piece: MeshInstance3D) -> AABB:
	return (global_transform.affine_inverse() * piece.global_transform) * piece.mesh.get_aabb()


## Everything drawn, as one box in this body's own space.
func bounds() -> AABB:
	var all := AABB()
	var first := true
	for piece: MeshInstance3D in parts():
		all = box_of(piece) if first else all.merge(box_of(piece))
		first = false
	return all


## The colour `part_name` is drawn in right now.
func colour_of(part_name: String) -> Color:
	var found := part(part_name)
	var material := null if found == null else found.material_override as StandardMaterial3D
	return material.albedo_color if material != null else Color()


func rig() -> FigureRig:
	return _rig


## What this figure is doing that its movement does not say. Told by whoever knows.
func act(to: FigureMotion.Act) -> void:
	_animator.set_act(to)


func acting() -> FigureMotion.Act:
	return _animator.act


func _physics_process(delta: float) -> void:
	advance(delta)


## Move the figure `delta` seconds on, from how its body moved since the last call.
func advance(delta: float) -> void:
	if _rig == null or _anchor == null or delta <= 0.0:
		return
	var at := _anchor.global_position
	var velocity := (at - _was) / delta if _seen else Vector3.ZERO
	_was = at
	_seen = true
	if velocity.length() > TELEPORT_SPEED:
		velocity = Vector3.ZERO
	move(delta, velocity)


## Move the figure `delta` seconds on as a body travelling at `velocity`.
func move(delta: float, velocity: Vector3) -> void:
	if _rig == null or _anchor == null:
		return
	var at := _anchor.global_position
	var forward := _anchor.global_transform.basis.z
	var place: Array = FigurePlaces.at(at) if _animator.speed() < FigureMotion.STILL else []
	_rig.apply(_animator.advance(delta, velocity, forward, _rig.shape, place))
	_face(place, delta)


## Seated or leaning, the figure faces its bench or counter rather than its pawn.
func _face(place: Array, delta: float) -> void:
	var turn := 0.0
	if _animator.is_settled() and not place.is_empty():
		turn = angle_difference(_anchor.global_rotation.y, float(place[1]))
	var root := _rig.root
	root.rotation.y = lerp_angle(root.rotation.y, turn, 1.0 - exp(-TURN_EASE * delta))
