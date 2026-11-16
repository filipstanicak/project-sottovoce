## **WHAT LIES ACROSS THE WATER.** ADR-0026. CLIENT ONLY.
##
## The greybox district ended at its own edge, with nothing beyond. A lagoon
## quarter has neighbours: other islands, their roofs and towers, fading into the
## haze. They are scenery and only scenery — past the fog, across water no pawn
## crosses — so they are the one place the district gets the pitched terracotta
## roofs its own walkable terraces cannot have.
##
## **THE SAME SKYLINE ON EVERY SCREEN.** Nothing here is random: every island is
## placed and built from its index, so two players describing the horizon to each
## other describe the same one.
class_name BackdropDresser
extends RefCounted

const ISLANDS := 9
## How far from the district's middle the islands stand.
const NEAR := 150.0
const FAR := 260.0
const HOUSES := 9

var _survey: DressingSurvey
var _batch: MeshBatch
var _palette: WorldPalette


func _init(survey: DressingSurvey, batch: MeshBatch, palette: WorldPalette) -> void:
	_survey = survey
	_batch = batch
	_palette = palette


func dress() -> void:
	var middle := _survey.bounds().get_center()
	for i: int in ISLANDS:
		var turn := TAU * (float(i) + 0.35 * _noise(i, 1)) / float(ISLANDS)
		var reach := lerpf(NEAR, FAR, _noise(i, 2))
		var at := Vector3(middle.x + cos(turn) * reach, 0.0, middle.y + sin(turn) * reach)
		_island(i, at, turn)


## A value in 0..1 that is the same for the same pair, always.
static func _noise(a: int, b: int) -> float:
	return float(("%d/%d" % [a, b]).hash() % 1000) / 1000.0


func _island(index: int, at: Vector3, turn: float) -> void:
	# Laid out along the shore it shows the district, so it reads as a skyline.
	var shore := Vector3(-sin(turn), 0.0, cos(turn))
	var inland := Vector3(cos(turn), 0.0, sin(turn))
	var width := lerpf(70.0, 120.0, _noise(index, 3))
	var facing := Basis(Vector3.UP, -turn)
	_batch.box(
		WorldMaterials.STONE,
		at + inland * 8.0 + Vector3(0.0, -1.0, 0.0),
		Vector3(40.0, 2.4, width + 10.0),
		_palette.quay,
		facing
	)
	for h: int in HOUSES:
		var mark := index * 31 + h
		var along := (float(h) + 0.5) / float(HOUSES) - 0.5
		var size := Vector3(
			lerpf(9.0, 14.0, _noise(mark, 4)),
			lerpf(6.0, 12.0, _noise(mark, 5)),
			width / float(HOUSES) * lerpf(0.8, 1.0, _noise(mark, 7))
		)
		var foot := at + shore * (along * width) + inland * (3.0 * _noise(mark, 8))
		_house(mark, foot, size, facing)
		# A second row behind and above the first, or a cypress in the gap.
		var behind := foot + inland * (size.x + 2.0) + shore * 2.5
		if mark % 3 == 0:
			_cypress(behind, lerpf(9.0, 14.0, _noise(mark, 9)))
		else:
			_house(mark + 7, behind, size + Vector3(0.0, 3.5, 0.0), facing)
	if index % 2 == 0:
		var base := at + shore * (width * 0.22) + inland * 9.0
		_tower(base, lerpf(24.0, 34.0, _noise(index, 6)), facing)


func _house(mark: int, foot: Vector3, size: Vector3, facing: Basis) -> void:
	var plaster := _palette.plasters[mark % _palette.plasters.size()]
	_batch.box(WorldMaterials.STONE, foot + Vector3(0.0, size.y * 0.5, 0.0), size, plaster, facing)
	_roof(foot + Vector3(0.0, size.y, 0.0), Vector2(size.x + 1.0, size.z + 1.0), 2.6, facing)
	# Windows on the side that looks at the district: dark specks that give the
	# wall a scale from across the water.
	var front := facing * Vector3(-size.x * 0.5 - 0.05, 0.0, 0.0)
	var columns := maxi(int(size.z / 2.6), 1)
	for row: int in maxi(int(size.y / 3.4), 1):
		for column: int in columns:
			var z := (float(column) + 0.5) / float(columns) * size.z - size.z * 0.5
			var pane := foot + front + facing * Vector3(0.0, 2.4 + float(row) * 3.2, z)
			_batch.box(
				WorldMaterials.GLASS, pane, Vector3(0.1, 1.5, 0.9), WorldPalette.DARK, facing
			)


func _cypress(foot: Vector3, height: float) -> void:
	_batch.column(WorldMaterials.STONE, foot, Vector2(1.5, height), 7, _palette.foliage, 0.0)


## A hipped roof turned to its island. `MeshBatch.hip_roof` is axis-aligned, so
## the roof is built round the origin and turned here.
func _roof(crown: Vector3, eaves: Vector2, rise: float, facing: Basis) -> void:
	var local := MeshBatch.new()
	local.hip_roof(WorldMaterials.ROOF, Vector3.ZERO, eaves, rise, WorldPalette.PLAIN)
	var vertices := local.vertices_of(WorldMaterials.ROOF)
	for i: int in range(0, vertices.size(), 3):
		# Stored clockwise; `tri` wants them counter-clockwise again.
		_batch.tri(
			WorldMaterials.ROOF,
			crown + facing * vertices[i],
			crown + facing * vertices[i + 2],
			crown + facing * vertices[i + 1],
			WorldPalette.PLAIN
		)


func _tower(foot: Vector3, height: float, facing: Basis) -> void:
	var size := Vector3(6.0, height, 6.0)
	_batch.box(
		WorldMaterials.STONE,
		foot + Vector3(0.0, height * 0.5, 0.0),
		size,
		_palette.plasters[0],
		facing
	)
	_roof(foot + Vector3(0.0, height, 0.0), Vector2(7.0, 7.0), 4.5, facing)
