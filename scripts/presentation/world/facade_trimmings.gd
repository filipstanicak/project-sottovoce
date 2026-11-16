## **WHAT HANGS ON A FACADE ABOVE THE HEADS.** ADR-0026, ART_BIBLE §4.1. CLIENT ONLY.
##
## The tiled eave under the roof line, a box of leaves under a window, an awning
## or a sign over a door. All of it is above 2.3 m, where §4.1 lets detail be *as
## rich as the budget allows*, and none of it rises above the wall it hangs on.
class_name FacadeTrimmings
extends RefCounted

## How far the eave reaches out, and how far it falls.
const EAVE_REACH := 0.6
const EAVE_FALL := 0.36
const AWNING_REACH := 0.9
const SIGN_Y := 2.75

var _batch: MeshBatch
var _palette: WorldPalette


func _init(batch: MeshBatch, palette: WorldPalette) -> void:
	_batch = batch
	_palette = palette


## A skirt of roof tile under the top of the wall: the roof line a street sees,
## on a building whose real roof is a terrace somebody may be standing on.
func eave(face: FacadeDresser.Face, top: float) -> void:
	var left := -EAVE_REACH
	var right := face.width + EAVE_REACH
	var low := top - EAVE_FALL
	var a := face.at(left, low, EAVE_REACH)
	var b := face.at(right, low, EAVE_REACH)
	var c := face.at(right, top - 0.02)
	var d := face.at(left, top - 0.02)
	_batch.quad(WorldMaterials.ROOF, a, b, c, d, WorldPalette.PLAIN)
	# Its underside, on rafters' shadow.
	var under := Vector3(0.0, 0.05, 0.0)
	_batch.quad(
		WorldMaterials.TIMBER, b - under, a - under, d - under, c - under, _palette.timber_dark
	)
	var across := absf(face.along.x) > 0.5
	var lip := Vector3(face.width + EAVE_REACH * 2.0, 0.06, 0.06)
	if not across:
		lip = Vector3(0.06, 0.06, face.width + EAVE_REACH * 2.0)
	_batch.box(
		WorldMaterials.TIMBER,
		face.at(face.width * 0.5, low - 0.01, EAVE_REACH),
		lip,
		_palette.timber_dark
	)


## A planter on the sill, and what grows in it.
func window_box(face: FacadeDresser.Face, u: float, sill: float) -> void:
	var across := absf(face.along.x) > 0.5
	var size := Vector3(0.96, 0.16, 0.2) if across else Vector3(0.2, 0.16, 0.96)
	_batch.box(WorldMaterials.TIMBER, face.at(u, sill - 0.06, 0.24), size, _palette.timber)
	for i: int in 4:
		var along := u - 0.36 + float(i) * 0.24
		var height := 0.16 + 0.07 * float((i * 7) % 3)
		_batch.column(
			WorldMaterials.STONE,
			face.at(along, sill, 0.24),
			Vector2(0.13, height),
			6,
			_palette.foliage,
			0.05
		)


## Over a door: an awning on one, a hanging sign on the next. Which is the
## building's own, by `mark`.
func over_the_door(
	face: FacadeDresser.Face, u: float, door_top: float, mark: int, owner: String
) -> void:
	if mark % 2 == 0:
		_awning(face, u, door_top + 0.35, owner)
	else:
		_sign(face, u + 1.05)


func _awning(face: FacadeDresser.Face, u: float, y: float, owner: String) -> void:
	var half := 0.95
	var stripe := WorldPalette.pick(_palette.stripes, owner)
	var a := face.at(u - half, y, AWNING_REACH)
	var b := face.at(u + half, y, AWNING_REACH)
	var c := face.at(u + half, y + 0.5, 0.02)
	var d := face.at(u - half, y + 0.5, 0.02)
	_batch.quad(WorldMaterials.CLOTH, a, b, c, d, stripe)
	_batch.quad(WorldMaterials.CLOTH, b, a, d, c, stripe)
	var drop := Vector3(0.0, 0.16, 0.0)
	_batch.quad(WorldMaterials.CLOTH, a - drop, b - drop, b, a, stripe)
	_batch.quad(WorldMaterials.CLOTH, b - drop, a - drop, a, b, stripe)


## A board on an iron arm, edge-on to the wall so the street reads it.
func _sign(face: FacadeDresser.Face, u: float) -> void:
	var across := absf(face.along.x) > 0.5
	var arm := Vector3(0.04, 0.04, 0.7) if across else Vector3(0.7, 0.04, 0.04)
	_batch.box(WorldMaterials.IRON, face.at(u, SIGN_Y + 0.3, 0.35), arm, _palette.iron)
	var board := Vector3(0.04, 0.42, 0.5) if across else Vector3(0.5, 0.42, 0.04)
	_batch.box(WorldMaterials.TIMBER, face.at(u, SIGN_Y, 0.42), board, _palette.timber)
