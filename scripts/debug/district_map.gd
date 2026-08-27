## **WHERE AM I, AND WHICH SPACE IS THIS?** US-0041.
##
## Asked for from the controls while testing the two new alley mouths: the greybox
## is one shade of grey everywhere, so the piazza, the Loggia and the streets are
## indistinguishable from inside them, and the mouths are 2.6 m gaps in a wall that
## does not exist yet.
##
## **IT TINTS THE WORLD AND DRAWS A MAP IN THE SAME COLOURS**, which is the point:
## a legend you have to translate is a legend you stop reading. Each street-level
## floor gets a hue from its index, so the two mouths are their own colour and can
## be found from across the district.
##
## **THIS IS NOT A MINIMAP, AND THE DISTINCTION IS LOAD-BEARING.** Never-do #12
## forbids one as a permanent design law — it "would convert an earned inference
## into a given fact", which is the whole game. This lives in `scripts/debug/`,
## which all three release presets exclude; `LocalPawnDriver` loads it behind
## `OS.has_feature("debug")` and an existence check; and
## `test_no_scene_references_debug.gd` refuses any `.tscn` that names it. **It
## cannot ship.** If it ever needs to, that is an ADR and a change to the six
## design laws, not a merge.
##
## Literals are allowed here: `test_no_literal_strings.gd` scans every layer except
## this one, because nothing below is ever shown to a player.
class_name DistrictMap
extends CanvasLayer

## What the other debug readouts must leave free. They are text with no background
## and this is opaque, so whichever drew second used to win.
const RESERVED_WIDTH := 292.0

## Pixels on a side. Large enough to tell a 2.6 m mouth from a wall at 120 m across.
const SIZE := 260.0

## **THE TOP EDGE CLEARS THE SHIPPING HUD'S TIER BLOCK.** This overlay is on layer
## 127 and the HUD is on layer 1, so it draws straight over it — and its panel is
## opaque, so before US-0073 was looked at it hid the tier indicator, the word and
## the source list completely. **The debug tool moves, not the HUD**: this is
## stripped from every release preset and the HUD's placement is UI_UX_SPEC §1's.
## Same call as `RESERVED_WIDTH` above, one layer out.
const HUD_TIER_BLOCK := 116.0

const MARGIN := Vector2(16.0, HUD_TIER_BLOCK)

## How saturated the world tint is. Enough to read a floor apart at distance,
## light enough that the greybox still looks like a greybox.
const TINT_SATURATION := 0.35
const MAP_SATURATION := 0.55

var _driver: LocalPawnDriver
var _view: Node3D
var _panel: Control
var _hues: Dictionary = {}


static func attach(to: Node, driver: LocalPawnDriver) -> Node:
	var overlay: CanvasLayer = (load("res://scripts/debug/district_map.gd") as GDScript).new()
	overlay.name = "DistrictMap"
	overlay._driver = driver
	to.add_child(overlay)
	return overlay


func _ready() -> void:
	layer = 127
	_assign_hues()
	_panel = Control.new()
	_panel.position = MARGIN
	_panel.custom_minimum_size = Vector2(SIZE, SIZE)
	_panel.draw.connect(_draw_map)
	add_child(_panel)
	_tint_the_world.call_deferred()


## A hue per street-level floor, from its index rather than a table, so a floor
## added to `VetraioLayout` gets a colour without anybody choosing one.
func _assign_hues() -> void:
	var streets := _street_floors()
	for i: int in streets.size():
		_hues[str(streets[i][0])] = float(i) / float(maxi(streets.size(), 1))


func _street_floors() -> Array:
	var out: Array = []
	for row: Array in VetraioLayout.FLOORS:
		if is_equal_approx(float(row[5]), VetraioLayout.STREET_Y):
			out.append(row)
	return out


## **THE SAME COLOURS, ON THE GROUND.** Found by node name: the generator emits one
## `StaticBody3D` per floor under `Geometry`, each with a `Mesh` child, so a
## material override needs no change to the generated scene and none to the art.
func _tint_the_world() -> void:
	var geometry := _find_geometry(get_tree().get_root())
	if geometry == null:
		return
	for row: Array in _street_floors():
		var mesh := geometry.get_node_or_null("%s/Mesh" % str(row[0])) as MeshInstance3D
		if mesh == null:
			continue
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color.from_hsv(float(_hues[str(row[0])]), TINT_SATURATION, 0.82)
		mesh.material_override = paint


func _find_geometry(node: Node) -> Node:
	if node.name == "Geometry":
		return node
	for child: Node in node.get_children():
		var hit := _find_geometry(child)
		if hit != null:
			return hit
	return null


func _process(_delta: float) -> void:
	if _panel != null:
		_panel.queue_redraw()


## North is up and the map is the district's own 120 m square, so a position reads
## straight off `VetraioLayout` without a camera or a projection to get wrong.
func _to_map(at: Vector2) -> Vector2:
	return at / VetraioLayout.MAP_SIZE * SIZE


func _draw_map() -> void:
	_panel.draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.06, 0.06, 0.07, 0.85))
	_draw_floors()
	_draw_blocks()
	_draw_crowd()
	_draw_player()
	_panel.draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(1, 1, 1, 0.25), false, 1.0)


func _draw_floors() -> void:
	for row: Array in _street_floors():
		var at := _to_map(Vector2(float(row[1]), float(row[2])))
		var span := _to_map(Vector2(float(row[3]), float(row[4])))
		var hue := float(_hues.get(str(row[0]), 0.0))
		_panel.draw_rect(Rect2(at, span), Color.from_hsv(hue, MAP_SATURATION, 0.85))


## **THE BUILDING MASSES, BECAUSE THE HOLES ARE THE POINT.** Anything drawn in
## neither a floor colour nor a block colour is a place with no ground at all —
## which is how the 60 x 6 m void between the piazza and the Loggia looked before
## the two mouths were cut, and how the strip CIRC-B walks off still looks.
func _draw_blocks() -> void:
	for row: Array in VetraioLayout.BLOCKS:
		var at := _to_map(Vector2(float(row[1]), float(row[2])))
		var span := _to_map(Vector2(float(row[3]), float(row[4])))
		_panel.draw_rect(Rect2(at, span), Color(0.20, 0.19, 0.22))


## Every NPC this client is drawing, from `NpcView`'s own bodies. Read-only, and
## by child rather than by index, because the view owns which indices it holds.
func _draw_crowd() -> void:
	if _view == null:
		_view = _find_view(get_tree().get_root())
	if _view == null:
		return
	for body: Node in _view.get_children():
		var at := (body as Node3D).global_position
		# A body under the street has fallen out of the world — CIRC-B walks four
		# members off the edge every match. Drawn hollow so it cannot be mistaken
		# for a civilian standing there.
		var fallen := at.y < VetraioLayout.STREET_Y - 1.0
		var colour := Color(1.0, 0.35, 0.35) if fallen else Color(0.95, 0.95, 0.95, 0.8)
		_panel.draw_circle(_to_map(Vector2(at.x, at.z)), 2.0 if fallen else 1.5, colour)


func _find_view(node: Node) -> Node3D:
	if node is NpcView:
		return node as Node3D
	for child: Node in node.get_children():
		var hit := _find_view(child)
		if hit != null:
			return hit
	return null


## The pawn, and which way it is looking — a dot alone cannot tell you whether the
## gap ahead is the mouth or the drop beside it.
func _draw_player() -> void:
	if _driver == null or _driver.ctx == null:
		return
	var at := _driver.ctx.position as Vector3
	var here := _to_map(Vector2(at.x, at.z))
	var yaw := float(_driver.ctx.yaw)
	var facing := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(facing.y, -facing.x)
	var nose := here + facing * 7.0
	_panel.draw_colored_polygon(
		PackedVector2Array(
			[nose, here - facing * 3.0 + side * 4.0, here - facing * 3.0 - side * 4.0]
		),
		Color(1.0, 0.9, 0.2)
	)
