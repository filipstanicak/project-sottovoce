## **WHO AM I HUNTING?** UI_UX_SPEC §1, US-0073, ASM-0030. CLIENT ONLY.
##
## Unknown until a lock completes, then revealed **permanently for that contract**.
## The reveal is what `TUN-COMPASS-LOCK-FILL-TIME` buys: 1.6 s of holding a
## contract in a 25° cone with a clear line, which is the price of turning *a
## direction* into *a person*.
##
## **IT SHOWS THAT YOU KNOW, NOT WHO — AND THAT IS A REAL LIMIT, NOT A STUB.**
## `NET-S2C-*` carries no persona for the contract and must not: ASM-0030 says a
## client learns its contract's appearance by **looking**, and the whole lock
## exists to make that looking cost something. So the widget can say *revealed*
## and cannot name a persona. A completed-lock status replaces the former empty box.
##
## **THE HONEST FIX IS A MESH, NOT A FIELD.** Once the lock completes the client
## already knows which body it locked, and the persona is readable from the pawn it
## is drawing — that is US-0046's `PersonaBody` and it needs the lock to name a
## slot. Adding the persona to the wire instead would hand every client its
## contract's identity on the tick the contract is assigned, which is the leak
## `NETWORK_PROTOCOL` §9's checklist line forbids.
class_name PortraitWidget
extends Control

const SIZE := Vector2(180.0, 220.0)
const MARGIN := Vector2(96.0, 56.0)
const FRAME_WIDTH := 1.5
const LABEL_SIZE := 19

var palette: Palette = null

var _revealed: bool = false
var _font: Font = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	custom_minimum_size = SIZE
	offset_left = MARGIN.x
	offset_right = MARGIN.x + SIZE.x
	offset_top = MARGIN.y
	offset_bottom = MARGIN.y + SIZE.y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.contract_portrait_revealed.connect(_on_revealed)
	EventBus.contract_assigned.connect(_on_assigned)


func _exit_tree() -> void:
	if EventBus.contract_portrait_revealed.is_connected(_on_revealed):
		EventBus.contract_portrait_revealed.disconnect(_on_revealed)
	if EventBus.contract_assigned.is_connected(_on_assigned):
		EventBus.contract_assigned.disconnect(_on_assigned)


func _on_revealed(_persona: StringName) -> void:
	_revealed = true
	queue_redraw()


## **A NEW CONTRACT IS A NEW UNKNOWN.** `CompassLock` resets its arc and its
## portrait on reassignment for exactly this reason (US-0058): a reveal earned
## against one person says nothing about the next, and a portrait that persisted
## across a repair would be free identification of somebody you have never looked
## at.
func _on_assigned(_reason: int) -> void:
	_revealed = false
	queue_redraw()


func is_revealed() -> bool:
	return _revealed


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), palette.plate, true)
	_caption(Strings.get_text(&"ui.contract.label"), 32.0, 15)
	if _revealed:
		_draw_identified()
		return
	# A featureless bust communicates missing identity, never a guessed persona.
	draw_circle(Vector2(90.0, 92.0), 22.0, palette.text_dim)
	draw_style_box(_shoulders(), Rect2(46.0, 122.0, 88.0, 40.0))
	_caption(Strings.get_text(&"ui.contract.unknown"), 196.0, LABEL_SIZE)


func _caption(text: String, baseline: float, font_size: int) -> void:
	draw_string(
		_font,
		Vector2(8.0, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		SIZE.x - 16.0,
		font_size,
		palette.text
	)


func _shoulders() -> StyleBoxFlat:
	var shape := StyleBoxFlat.new()
	shape.bg_color = palette.text_dim
	shape.corner_radius_top_left = 32
	shape.corner_radius_top_right = 32
	return shape


## The bridge supplies no persona yet. A completed lock is a fact we may show;
## a face would be invented. This status does not complete US-0073's portrait.
func _draw_identified() -> void:
	draw_arc(Vector2(90.0, 112.0), 32.0, 0.0, TAU, 48, palette.text_dim, FRAME_WIDTH, true)
	draw_polyline(
		PackedVector2Array([Vector2(74.0, 112.0), Vector2(86.0, 124.0), Vector2(108.0, 100.0)]),
		palette.text,
		3.0,
		true
	)
	_caption(Strings.get_text(&"ui.contract.identified"), 196.0, LABEL_SIZE)
