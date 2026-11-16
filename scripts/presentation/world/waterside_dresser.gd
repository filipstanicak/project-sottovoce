## **WHAT STANDS IN THE WATER OFF A QUAY.** ADR-0026. CLIENT ONLY.
##
## Mooring poles along every parapet with water beyond it, and a boat tied to
## some of them. Out in the canal, a metre and more past the parapet: nothing a
## pawn can touch, hide behind or stand on, and all of it below the street.
class_name WatersideDresser
extends RefCounted

## How far apart the mooring poles stand along a quay, and how far off it.
const POLE_SPACING := 9.0
const POLE_OFFSET := 1.1
## A boat lies at one pole in this many.
const BOAT_ONE_IN := 3
const BOAT_LENGTH := 3.4
const BOAT_BEAM := 1.15
## A canal narrower than this has no room for a boat beside the poles.
const BOAT_ROOM := 3.2

var _survey: DressingSurvey
var _batch: MeshBatch
var _palette: WorldPalette


func _init(survey: DressingSurvey, batch: MeshBatch, palette: WorldPalette) -> void:
	_survey = survey
	_batch = batch
	_palette = palette


func dress() -> void:
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.PARAPET):
		_moorings(part)


func _moorings(part: DressingSurvey.Part) -> void:
	var along_x := part.size.x >= part.size.z
	var length := part.size.x if along_x else part.size.z
	if length < POLE_SPACING:
		return
	var run := Vector3.RIGHT if along_x else Vector3.BACK
	var out := Vector3.BACK if along_x else Vector3.RIGHT
	var middle := Vector3(part.centre.x, 0.0, part.centre.z)
	if _is_ground(middle + out):
		out = -out
	var count := int(length / POLE_SPACING)
	for i: int in count:
		var along := (float(i) + 0.5) * length / float(count) - length * 0.5
		var foot := middle + run * along + out * POLE_OFFSET
		if _is_ground(foot) or _is_ground(foot + out * 0.6):
			continue
		_pole(foot)
		var berth := foot + out * (BOAT_BEAM * 0.5 + 0.25) + run * 0.6
		var clear := not _is_ground(berth + out * (BOAT_ROOM - POLE_OFFSET))
		if (part.name + str(i)).hash() % BOAT_ONE_IN == 0 and clear:
			_boat(berth, run, out)


func _is_ground(at: Vector3) -> bool:
	var flat := Vector2(at.x, at.z)
	return _survey.ground_at(flat) or _survey.block_top_at(flat, null) > 0.0


func _pole(foot: Vector3) -> void:
	var base := Vector3(foot.x, GroundDresser.WATER_Y - 1.0, foot.z)
	_batch.column(WorldMaterials.TIMBER, base, Vector2(0.09, 2.7), 7, _palette.timber_dark)
	_batch.column(
		WorldMaterials.STONE, base + Vector3.UP * 2.7, Vector2(0.1, 0.16), 7, _palette.linen, 0.07
	)


## A small open boat lying along the quay: a hull that narrows to a point at
## each end, a floor, two thwarts.
func _boat(at: Vector3, run: Vector3, out: Vector3) -> void:
	var water := Vector3(at.x, GroundDresser.WATER_Y, at.z)
	var half := BOAT_LENGTH * 0.5
	var beam := BOAT_BEAM * 0.5
	var keel := water - Vector3.UP * 0.12
	var rail := water + Vector3.UP * 0.34
	var hull := _palette.timber_dark
	for end: float in [-1.0, 1.0]:
		var tip := rail + run * (end * (half + 0.75)) + Vector3.UP * 0.12
		for side: float in [-1.0, 1.0]:
			var top := rail + run * (end * half) + out * (side * beam)
			var low := keel + run * (end * half) + out * (side * beam * 0.6)
			var mid_top := rail + out * (side * beam)
			var mid_low := keel + out * (side * beam * 0.6)
			# Both ways round: a plank is seen from outside and from in the boat.
			_batch.quad(WorldMaterials.TIMBER, mid_low, low, top, mid_top, hull)
			_batch.quad(WorldMaterials.TIMBER, low, mid_low, mid_top, top, hull)
			_batch.tri(WorldMaterials.TIMBER, low, tip, top, hull)
			_batch.tri(WorldMaterials.TIMBER, tip, low, top, hull)
	var inside := Basis(run, Vector3.UP, out)
	_batch.box(
		WorldMaterials.TIMBER,
		water + Vector3.UP * 0.02,
		Vector3(BOAT_LENGTH, 0.05, BOAT_BEAM * 0.8),
		_palette.timber,
		inside
	)
	for seat: float in [-0.7, 0.8]:
		_batch.box(
			WorldMaterials.TIMBER,
			water + run * seat + Vector3.UP * 0.26,
			Vector3(0.22, 0.04, BOAT_BEAM),
			_palette.timber,
			inside
		)
