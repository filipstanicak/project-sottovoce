## **THE THINGS A PAWN GETS OVER, SITS ON AND HIDES IN.** ADR-0026. CLIENT ONLY.
##
## Stalls, benches, parapets and the concealment props are the solids a player
## uses rather than walks round, so each has to keep saying what it is for: a
## counter is still a counter-high slab, a bench still a seat-high one. What is
## added sits above them — an awning 2.4 m up, out of the band players are read
## in (ART_BIBLE §4.1) — or on them, where it is lower than a vault.
class_name PropDresser
extends RefCounted

const AWNING_EAVE := 2.4
const AWNING_RIDGE := 2.95
const AWNING_OVERHANG := 0.45
const POST := 0.09

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


func dress() -> void:
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.STALL):
		_repaint(part, WorldMaterials.TIMBER, _palette.timber)
		_stall(part)
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.PARAPET):
		_repaint(part, WorldMaterials.STONE, _palette.trim)
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.BENCH):
		_repaint(part, WorldMaterials.STONE, _palette.trim)
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.PROP):
		_repaint(part, WorldMaterials.TIMBER, _palette.timber)
		_hiding_place(part)


func _repaint(part: DressingSurvey.Part, key: StringName, colour: Color) -> void:
	if part.mesh == null:
		return
	part.mesh.material_override = _materials.of(key)
	part.mesh.set_instance_shader_parameter(&"tint", colour)
	part.mesh.set_instance_shader_parameter(&"seed", float(part.name.hash() % 89))


## A market stall: four posts, a striped awning with a ridge along the counter,
## and goods down the middle of it.
func _stall(part: DressingSurvey.Part) -> void:
	var along_x := part.size.x >= part.size.z
	var half := Vector2(part.size.x, part.size.z) * 0.5
	var top := part.top()
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var foot := part.centre + Vector3(x * (half.x - POST), 0.0, z * (half.y - POST))
			var height := AWNING_EAVE - top
			_batch.box(
				WorldMaterials.TIMBER,
				Vector3(foot.x, top + height * 0.5, foot.z),
				Vector3(POST, height, POST),
				_palette.timber_dark
			)
	_awning(part, along_x)
	_goods(part, along_x)


func _awning(part: DressingSurvey.Part, along_x: bool) -> void:
	var length := (part.size.x if along_x else part.size.z) * 0.5 + 0.2
	var reach := (part.size.z if along_x else part.size.x) * 0.5 + AWNING_OVERHANG
	var run := Vector3.RIGHT if along_x else Vector3.BACK
	var out := Vector3.BACK if along_x else Vector3.RIGHT
	var middle := Vector3(part.centre.x, 0.0, part.centre.z)
	var ridge_a := middle - run * length + Vector3.UP * AWNING_RIDGE
	var ridge_b := middle + run * length + Vector3.UP * AWNING_RIDGE
	var stripe := WorldPalette.pick(_palette.stripes, part.name)
	for side: float in [-1.0, 1.0]:
		var eave_a := middle - run * length + out * (side * reach) + Vector3.UP * AWNING_EAVE
		var eave_b := middle + run * length + out * (side * reach) + Vector3.UP * AWNING_EAVE
		# Both sides of the cloth: it is seen from underneath more than from above.
		_batch.quad(WorldMaterials.CLOTH, eave_a, eave_b, ridge_b, ridge_a, stripe)
		_batch.quad(WorldMaterials.CLOTH, eave_b, eave_a, ridge_a, ridge_b, stripe)
		var drop := Vector3.UP * 0.2
		_batch.quad(WorldMaterials.CLOTH, eave_a - drop, eave_b - drop, eave_b, eave_a, stripe)
		_batch.quad(WorldMaterials.CLOTH, eave_b - drop, eave_a - drop, eave_a, eave_b, stripe)
	var pole := Vector3(length * 2.0, 0.07, 0.07) if along_x else Vector3(0.07, 0.07, length * 2.0)
	_batch.box(
		WorldMaterials.TIMBER,
		middle + Vector3.UP * (AWNING_RIDGE - 0.05),
		pole,
		_palette.timber_dark
	)


## Pots, sacks and crates along the counter's middle, lower than anything a
## player has to see past. Which goes where is the stall's own, by its name.
func _goods(part: DressingSurvey.Part, along_x: bool) -> void:
	var length := part.size.x if along_x else part.size.z
	var run := Vector3.RIGHT if along_x else Vector3.BACK
	var count := int(length / 0.55)
	var top := Vector3(part.centre.x, part.top(), part.centre.z)
	for i: int in count:
		var mark := (part.name + str(i)).hash()
		if mark % 5 == 0:
			continue
		var at := top + run * ((float(i) + 0.5) * length / float(count) - length * 0.5)
		_ware(at, mark)


## One thing for sale: a jug, a basket, a crate, a bottle or a bolt of cloth.
func _ware(at: Vector3, mark: int) -> void:
	match mark % 5:
		0:
			_batch.column(WorldMaterials.STONE, at, Vector2(0.1, 0.22), 8, _palette.clay, 0.14)
			_batch.column(
				WorldMaterials.STONE,
				at + Vector3.UP * 0.22,
				Vector2(0.14, 0.1),
				8,
				_palette.clay,
				0.06
			)
		1:
			_batch.column(WorldMaterials.TIMBER, at, Vector2(0.17, 0.14), 9, _palette.straw, 0.22)
		2:
			_batch.box(
				WorldMaterials.TIMBER,
				at + Vector3.UP * 0.12,
				Vector3(0.36, 0.24, 0.3),
				_palette.timber
			)
		3:
			_batch.column(WorldMaterials.STONE, at, Vector2(0.07, 0.2), 7, _palette.shutter)
			_batch.column(
				WorldMaterials.STONE,
				at + Vector3.UP * 0.2,
				Vector2(0.07, 0.12),
				7,
				_palette.shutter,
				0.025
			)
		_:
			var bolt := WorldPalette.pick(_palette.stripes, str(mark))
			_batch.box(WorldMaterials.CLOTH, at + Vector3.UP * 0.07, Vector3(0.4, 0.14, 0.26), bolt)


## A concealment prop: a hay cart, a pile of crates under a cloth, or a well —
## the same one for the same prop on every screen.
func _hiding_place(part: DressingSurvey.Part) -> void:
	var top := Vector3(part.centre.x, part.top(), part.centre.z)
	match part.name.hash() % 3:
		0:
			_batch.column(WorldMaterials.STONE, top, Vector2(0.78, 0.6), 10, _palette.straw, 0.3)
			for x: float in [-1.0, 1.0]:
				var rail := top + Vector3(x * (part.size.x * 0.5 - 0.04), 0.14, 0.0)
				_batch.box(
					WorldMaterials.TIMBER,
					rail,
					Vector3(0.07, 0.28, part.size.z),
					_palette.timber_dark
				)
		1:
			_batch.box(
				WorldMaterials.TIMBER,
				top + Vector3(0.2, 0.25, 0.1),
				Vector3(0.9, 0.5, 0.8),
				_palette.timber
			)
			_batch.box(
				WorldMaterials.CLOTH,
				top + Vector3(-0.3, 0.1, -0.2),
				Vector3(0.9, 0.2, 1.0),
				_palette.stripes[0]
			)
		_:
			_well_head(part, top)


func _well_head(part: DressingSurvey.Part, top: Vector3) -> void:
	for x: float in [-1.0, 1.0]:
		var foot := top + Vector3(x * (part.size.x * 0.5 - 0.1), 0.65, 0.0)
		_batch.box(WorldMaterials.TIMBER, foot, Vector3(0.12, 1.3, 0.12), _palette.timber_dark)
	_batch.box(
		WorldMaterials.TIMBER,
		top + Vector3(0.0, 1.36, 0.0),
		Vector3(part.size.x, 0.12, 0.14),
		_palette.timber_dark
	)
	_batch.box(
		WorldMaterials.STONE,
		top + Vector3(0.0, 0.04, 0.0),
		Vector3(part.size.x - 0.3, 0.08, part.size.z - 0.3),
		_palette.timber
	)
