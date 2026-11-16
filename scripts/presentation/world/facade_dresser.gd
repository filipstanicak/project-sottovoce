## **WHAT MAKES A BOX A BUILDING.** ADR-0026, ART_BIBLE §4. CLIENT ONLY.
##
## Every block in the greybox is one box. This paints it — plaster in the
## building's own colour, or coursed stone if it can be climbed — and hangs on it
## what a facade has: a plinth, a string course at the balcony line, a cornice,
## shuttered windows above, a door here and there, a lantern on a bracket.
##
## **THE STRATA ARE THE GAME'S OWN.** §4 asks for horizontal banding so the layer a
## player stands on is legible; the string course sits at 3.5 m because that is
## where the balcony is, and the cornice closes the wall where the roof begins.
##
## **AND EYE HEIGHT IS LEFT ALONE.** §4.1: between 1.4 m and 1.9 m is where players
## read each other. Windows start above it, the lanterns hang above it, and the
## only thing in it is a door every third bay, dark and flat.
##
## **NOTHING HERE RISES ABOVE THE WALL IT IS ON**, so a roof a pawn can stand on is
## exactly as flat and as clear against the sky as it was (§4, *silhouette-clean
## architecture*). The one roof with a shape is the bell tower's, 22 m up.
class_name FacadeDresser
extends RefCounted

## Below this a block is a wall, not a building: it gets a coping and nothing else.
const WALL_HEIGHT := 3.0
## Above this a block is a tower.
const TOWER_HEIGHT := 12.0
## Where the upper storey starts — the balcony line — and how tall a storey is.
const STOREY_LINE := 3.5
const STOREY := 3.6
const BAY := 3.4
const WINDOW := Vector2(1.0, 1.7)
const SILL := 1.0
const DOOR := Vector2(1.3, 2.3)
const LANTERN_Y := 3.0
## One window in this many is lit.
const LIT_ONE_IN := 6


## One side of a block: where it starts, which way it runs and which way it looks.
class Face:
	var start := Vector3.ZERO
	var along := Vector3.ZERO
	var normal := Vector3.ZERO
	var width := 0.0

	func at(u: float, y: float, out: float = 0.0) -> Vector3:
		return start + along * u + normal * out + Vector3(0.0, y, 0.0)


var _survey: DressingSurvey
var _batch: MeshBatch
var _materials: WorldMaterials
var _palette: WorldPalette
var _trimmings: FacadeTrimmings


func _init(
	survey: DressingSurvey, batch: MeshBatch, materials: WorldMaterials, palette: WorldPalette
) -> void:
	_survey = survey
	_batch = batch
	_materials = materials
	_palette = palette
	_trimmings = FacadeTrimmings.new(batch, palette)


func dress() -> void:
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.BLOCK):
		_paint(part)
		if part.top() < WALL_HEIGHT:
			_coping(part)
			continue
		for face: Face in faces_of(part):
			_face(part, face)
		if part.top() > TOWER_HEIGHT:
			_belfry(part)


## The four sides of a block, each running left to right as seen from outside.
static func faces_of(part: DressingSurvey.Part) -> Array[Face]:
	var r := part.rect()
	var out: Array[Face] = []
	out.append(_side(Vector3(r.end.x, 0.0, r.position.y), Vector3.LEFT, Vector3.FORWARD, r.size.x))
	out.append(_side(Vector3(r.position.x, 0.0, r.end.y), Vector3.RIGHT, Vector3.BACK, r.size.x))
	out.append(
		_side(Vector3(r.position.x, 0.0, r.position.y), Vector3.BACK, Vector3.LEFT, r.size.y)
	)
	out.append(_side(Vector3(r.end.x, 0.0, r.end.y), Vector3.FORWARD, Vector3.RIGHT, r.size.y))
	return out


static func _side(start: Vector3, along: Vector3, normal: Vector3, width: float) -> Face:
	var face := Face.new()
	face.start = start
	face.along = along
	face.normal = normal
	face.width = width
	return face


func _paint(part: DressingSurvey.Part) -> void:
	if part.mesh == null:
		return
	var key := WorldMaterials.CLIMB if part.climbable else WorldMaterials.PLASTER
	part.mesh.material_override = _materials.of(key)
	var colour := WorldPalette.PLAIN if part.climbable else plaster_of(part)
	part.mesh.set_instance_shader_parameter(&"tint", colour)
	part.mesh.set_instance_shader_parameter(&"seed", float(part.name.hash() % 89))


## A building's plaster: the same for the same building on every screen.
func plaster_of(part: DressingSurvey.Part) -> Color:
	return WorldPalette.pick(_palette.plasters, part.name)


## A garden wall's capping stone, flush with its top.
func _coping(part: DressingSurvey.Part) -> void:
	_batch.box(
		WorldMaterials.STONE,
		Vector3(part.centre.x, part.top() - 0.07, part.centre.z),
		Vector3(part.size.x + 0.12, 0.14, part.size.z + 0.12),
		_palette.trim
	)


## A part `depth` proud of the wall, `size` wide and tall, centred `at` (along
## the face, and up it).
func _slab(
	key: StringName, face: Face, at: Vector2, size: Vector2, depth: float, colour: Color
) -> void:
	var across := absf(face.along.x) > 0.5
	var box := Vector3(size.x, size.y, depth) if across else Vector3(depth, size.y, size.x)
	_batch.box(key, face.at(at.x, at.y, depth * 0.5 - 0.01), box, colour)


func _band(face: Face, y: float, height: float, depth: float, colour: Color) -> void:
	var size := Vector2(face.width + depth * 2.0, height)
	_slab(WorldMaterials.STONE, face, Vector2(face.width * 0.5, y), size, depth, colour)


func _face(part: DressingSurvey.Part, face: Face) -> void:
	var top := part.top()
	var probe := face.at(face.width * 0.5, 0.0, 0.3)
	var base := _survey.block_top_at(Vector2(probe.x, probe.z), part)
	if base >= top - 1.0:
		return
	if base < 0.1:
		_band(face, 0.28, 0.56, 0.08, _palette.quay)
	if base < STOREY_LINE and top > STOREY_LINE + 2.0:
		_band(face, STOREY_LINE, 0.2, 0.1, _palette.trim)
	_band(face, top - 0.52, 0.2, 0.1, _palette.trim)
	if top <= TOWER_HEIGHT:
		_trimmings.eave(face, top)
	var bays := maxi(int((face.width - 1.0) / BAY), 1)
	for i: int in bays:
		_bay(part, face, i, (float(i) + 0.5) * face.width / float(bays))


func _bay(part: DressingSurvey.Part, face: Face, index: int, u: float) -> void:
	var probe := face.at(u, 0.0, 0.3)
	var base := _survey.block_top_at(Vector2(probe.x, probe.z), part)
	var top := part.top()
	var ceiling := top - (5.0 if top > TOWER_HEIGHT else 0.0)
	var mark := (part.name + str(index) + str(face.normal)).hash()
	var floor_y := STOREY_LINE
	while floor_y + 3.0 <= ceiling:
		if floor_y >= base:
			var lit := (mark + int(floor_y * 10.0)) % LIT_ONE_IN == 0
			_window(face, u, floor_y + SILL, lit, part.name)
			if (mark + int(floor_y)) % 3 == 0:
				_trimmings.window_box(face, u, floor_y + SILL)
		floor_y += STOREY
	if base > 0.1 or top < STOREY_LINE + 2.0:
		return
	if index % 3 == 1:
		_door(face, u)
		_trimmings.over_the_door(face, u, DOOR.y, mark, part.name)
	if index % 4 == 2:
		_lantern(face, u + 1.1)


func _window(face: Face, u: float, sill: float, lit: bool, owner: String) -> void:
	var middle := sill + WINDOW.y * 0.5
	var light := _palette.window_glow if lit else WorldPalette.DARK
	_slab(WorldMaterials.GLASS, face, Vector2(u, middle), WINDOW, 0.03, light)
	var bars := _palette.timber_dark
	_slab(WorldMaterials.TIMBER, face, Vector2(u, middle), Vector2(0.05, WINDOW.y), 0.045, bars)
	_slab(
		WorldMaterials.TIMBER,
		face,
		Vector2(u, sill + WINDOW.y * 0.62),
		Vector2(WINDOW.x, 0.05),
		0.045,
		bars
	)
	var stone := _palette.trim
	_slab(
		WorldMaterials.STONE,
		face,
		Vector2(u, sill - 0.07),
		Vector2(WINDOW.x + 0.36, 0.14),
		0.16,
		stone
	)
	var head := sill + WINDOW.y + 0.09
	_slab(WorldMaterials.STONE, face, Vector2(u, head), Vector2(WINDOW.x + 0.3, 0.18), 0.12, stone)
	var leaf := WorldPalette.pick([_palette.shutter, _palette.timber, _palette.timber_dark], owner)
	for side: float in [-1.0, 1.0]:
		var jamb := u + side * (WINDOW.x * 0.5 + 0.06)
		_slab(
			WorldMaterials.STONE, face, Vector2(jamb, middle), Vector2(0.12, WINDOW.y), 0.08, stone
		)
		var open := u + side * (WINDOW.x * 0.5 + 0.36)
		_slab(
			WorldMaterials.TIMBER, face, Vector2(open, middle), Vector2(0.46, WINDOW.y), 0.05, leaf
		)


func _door(face: Face, u: float) -> void:
	var wood := _palette.timber_dark
	_slab(WorldMaterials.TIMBER, face, Vector2(u, DOOR.y * 0.5), DOOR, 0.04, wood)
	var stone := _palette.trim
	var head := Vector2(DOOR.x + 0.4, 0.22)
	_slab(WorldMaterials.STONE, face, Vector2(u, DOOR.y + 0.11), head, 0.12, stone)
	for side: float in [-1.0, 1.0]:
		var jamb := u + side * (DOOR.x * 0.5 + 0.09)
		_slab(
			WorldMaterials.STONE,
			face,
			Vector2(jamb, DOOR.y * 0.5),
			Vector2(0.18, DOOR.y),
			0.1,
			stone
		)


## An iron bracket and the lantern hanging from its end.
func _lantern(face: Face, u: float) -> void:
	var across := absf(face.along.x) > 0.5
	var arm := Vector3(0.05, 0.05, 0.6) if across else Vector3(0.6, 0.05, 0.05)
	_batch.box(WorldMaterials.IRON, face.at(u, LANTERN_Y + 0.25, 0.3), arm, _palette.iron)
	var hang := face.at(u, LANTERN_Y, 0.55)
	_batch.box(WorldMaterials.GLASS, hang, Vector3(0.16, 0.26, 0.16), _palette.window_glow)
	_batch.box(
		WorldMaterials.IRON,
		hang + Vector3(0.0, 0.16, 0.0),
		Vector3(0.22, 0.06, 0.22),
		_palette.iron
	)
	_batch.box(
		WorldMaterials.IRON,
		hang - Vector3(0.0, 0.15, 0.0),
		Vector3(0.18, 0.04, 0.18),
		_palette.iron
	)


## The bell tower's head: two dark openings a side, and the one pitched roof in
## the district — 22 m up, where no pawn stands and no silhouette is read.
func _belfry(part: DressingSurvey.Part) -> void:
	var top := part.top()
	for face: Face in faces_of(part):
		_band(face, top - 4.6, 0.24, 0.14, _palette.trim)
		for u: float in [face.width * 0.3, face.width * 0.7]:
			var opening := Vector2(1.1, 2.6)
			_slab(
				WorldMaterials.GLASS, face, Vector2(u, top - 2.6), opening, 0.03, WorldPalette.DARK
			)
			var head := Vector2(opening.x + 0.3, 0.2)
			_slab(WorldMaterials.STONE, face, Vector2(u, top - 1.2), head, 0.12, _palette.trim)
	var crown := Vector3(part.centre.x, top, part.centre.z)
	var eaves := Vector2(part.size.x + 0.8, part.size.z + 0.8)
	_batch.hip_roof(WorldMaterials.ROOF, crown, eaves, part.size.x * 0.6, WorldPalette.PLAIN)
