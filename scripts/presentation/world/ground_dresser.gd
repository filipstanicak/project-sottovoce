## **THE GROUND, WHAT IT STANDS ON, AND THE WATER ROUND IT.** ADR-0026. CLIENT ONLY.
##
## The greybox district is slabs over nothing: between the piazza and the Loggia,
## along the Fondaco and all round the map there is a drop with a parapet on it.
## The art pass reads those drops as what a glassmakers' quarter would have there —
## canals, and a lagoon beyond — so the walkable ground becomes quays, the narrow
## floors over a drop become bridges, and one sheet of water lies under all of it.
##
## **NOTHING HERE IS SOLID.** A pawn that leaves the ground falls exactly as far as
## it did in the greybox; the water is a picture of the drop, not a floor in it.
class_name GroundDresser
extends RefCounted

## Where the water lies, below the street.
const WATER_Y := -1.3
## How far down the quays are drawn: past the water, so no gap shows under a swell.
const QUAY_DEPTH := 2.6
## The quay stands this far proud of the ground it carries, under the parapets.
const QUAY_LIP := 0.4
## The water reaches this far, in metres: past the fog, so its edge is never seen.
const WATER_REACH := 1600.0
## A street-level floor narrower than this, and at least twice as long, is a bridge.
const BRIDGE_WIDTH := 3.0
## Any floor narrower than this is a street of setts; wider is a paved square.
const STREET_WIDTH := 12.0
const ARCH_STEPS := 10
## The balcony's timbers.
const POST := 0.2
const POST_SPACING := 6.0
const JOIST_SPACING := 1.5

var _survey: DressingSurvey
var _batch: MeshBatch
var _materials: WorldMaterials
var _palette: WorldPalette


func _init(
	survey: DressingSurvey, batch: MeshBatch, materials: WorldMaterials, palette: WorldPalette
) -> void:
	_survey = survey
	_batch = batch
	_materials = materials
	_palette = palette


func dress(host: Node3D) -> void:
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.FLOOR):
		_pave(part)
		if part.top() > 1.0:
			_gallery(part)
		elif is_bridge(part):
			_bridge(part)
		else:
			_quay(part.rect(), part.bottom())
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.BLOCK):
		_quay(part.rect(), minf(part.bottom(), 0.0))
	_flood(host)


static func is_bridge(part: DressingSurvey.Part) -> bool:
	var narrow := minf(part.size.x, part.size.z)
	var long := maxf(part.size.x, part.size.z)
	return part.top() < 1.0 and narrow < BRIDGE_WIDTH and long >= narrow * 2.0


## Which of the ground shader's patterns a floor is laid in.
static func pattern_of(part: DressingSurvey.Part) -> float:
	if part.top() > 1.0:
		return WorldMaterials.BOARDS
	if minf(part.size.x, part.size.z) < STREET_WIDTH:
		return WorldMaterials.SETTS
	return WorldMaterials.PAVING


func _pave(part: DressingSurvey.Part) -> void:
	if part.mesh == null:
		return
	part.mesh.material_override = _materials.ground
	part.mesh.set_instance_shader_parameter(&"pattern", pattern_of(part))


## The stone a stretch of ground stands on, from `top` down past the water.
func _quay(rect: Rect2, top: float) -> void:
	var grown := rect.grow(QUAY_LIP)
	var centre := Vector3(grown.get_center().x, top - QUAY_DEPTH * 0.5, grown.get_center().y)
	_batch.box(
		WorldMaterials.STONE, centre, Vector3(grown.size.x, QUAY_DEPTH, grown.size.y), _palette.quay
	)


## A narrow floor over a drop: one arch under it, stepped, the full width.
func _bridge(part: DressingSurvey.Part) -> void:
	var along_x := part.size.x > part.size.z
	var length := maxf(part.size.x, part.size.z)
	var width := minf(part.size.x, part.size.z) + QUAY_LIP * 2.0
	var step := length / float(ARCH_STEPS)
	for i: int in ARCH_STEPS:
		var t := (float(i) + 0.5) / float(ARCH_STEPS)
		# Thin at the crown, down to the water at the springing.
		var depth := 0.35 + (QUAY_DEPTH - 0.35) * pow(absf(t * 2.0 - 1.0), 2.5)
		var run := (t - 0.5) * length
		var offset := Vector3(run, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, run)
		var size := Vector3(step, depth, width) if along_x else Vector3(width, depth, step)
		var centre := Vector3(part.centre.x, part.bottom() - depth * 0.5, part.centre.z)
		_batch.box(WorldMaterials.STONE, centre + offset, size, _palette.quay)


## A raised floor: joists under it, and posts along whichever long edge stands
## over a drop — there a post is outside the ground a pawn can reach.
func _gallery(part: DressingSurvey.Part) -> void:
	var along_x := part.size.x >= part.size.z
	var length := part.size.x if along_x else part.size.z
	var depth := part.size.z if along_x else part.size.x
	var underside := part.bottom()
	var count := int(length / JOIST_SPACING)
	for i: int in count:
		var run := (float(i) + 0.5) * length / float(count) - length * 0.5
		var at := part.centre + (Vector3(run, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, run))
		var size := Vector3(0.14, 0.2, depth) if along_x else Vector3(depth, 0.2, 0.14)
		_batch.box(
			WorldMaterials.TIMBER, Vector3(at.x, underside - 0.1, at.z), size, _palette.timber_dark
		)
	for side: float in [-1.0, 1.0]:
		_posts(part, along_x, side)


func _posts(part: DressingSurvey.Part, along_x: bool, side: float) -> void:
	var length := part.size.x if along_x else part.size.z
	var depth := part.size.z if along_x else part.size.x
	var out := Vector3(0.0, 0.0, side) if along_x else Vector3(side, 0.0, 0.0)
	var edge := part.centre + out * (depth * 0.5)
	if _survey.ground_at(Vector2(edge.x, edge.z) + Vector2(out.x, out.z) * 0.6):
		return
	var count := maxi(int(length / POST_SPACING), 1)
	var underside := part.bottom()
	for i: int in count + 1:
		var run := float(i) * length / float(count) - length * 0.5
		var along := Vector3(run, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, run)
		var foot := edge + along + out * (POST * 0.5)
		_batch.box(
			WorldMaterials.TIMBER,
			Vector3(foot.x, underside * 0.5, foot.z),
			Vector3(POST, underside, POST),
			_palette.timber
		)
		# The strut, from head height on the post up to the joists.
		var reach := 1.4
		var brace := Basis(Vector3(-out.z, 0.0, out.x), atan2(reach, underside - 2.0))
		_batch.box(
			WorldMaterials.TIMBER,
			Vector3(foot.x, (underside + 2.0) * 0.5, foot.z) - out * (reach * 0.5),
			Vector3(0.12, Vector2(reach, underside - 2.0).length(), 0.12),
			_palette.timber_dark,
			brace
		)


## One sheet of water under the whole district and out past the fog.
func _flood(host: Node3D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(WATER_REACH, WATER_REACH)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = _materials.water
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var middle := _survey.bounds().get_center()
	water.position = Vector3(middle.x, WATER_Y, middle.y)
	host.add_child(water)
