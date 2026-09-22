## **WHO AM I HUNTING?** UI_UX_SPEC §1, US-0073, ADR-0021. CLIENT ONLY.
##
## **THE PERSONA IS KNOWN FROM ASSIGNMENT** (ADR-0021, 2026-09-22): a hunter is
## told what their target looks like, and the search is *which of that persona's
## lookalikes moves like a player*. The mark this widget draws on a completed lock
## is the other half — `TUN-COMPASS-LOCK-FILL-TIME`'s 1.6 s of holding a contract
## in a 25° cone with a clear line, which is the price of turning *a direction*
## into *a body*, and it resets with the contract.
##
## **IT DRAWS NO FACE YET, AND THAT IS A BUILD STATE RATHER THAN A RULE.** Under
## ASM-0030 — void since ADR-0021 — the persona was withheld until the lock, and
## this docstring said the widget *must not* name one. What is true now is simpler:
## **no player has a persona server-side at all** until US-0078's lobby assigns
## one, so there is nothing to draw. When there is, the persona travels with the
## contract on `NET-S2C-CONTRACT-ASSIGNED` and this widget draws it from
## assignment, with the lock mark beside it.
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


func _on_revealed() -> void:
	_revealed = true
	queue_redraw()


## **A NEW CONTRACT IS A NEW BODY TO FIND.** `CompassLock` resets its arc and its
## latch on reassignment for exactly this reason (US-0058): a lock earned against
## one person says nothing about the next, and a mark that persisted across a
## repair would claim you had picked somebody out of the crowd that you never
## looked at. (The *persona* also changes with the contract, ADR-0021.)
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


## The mark for a completed lock. No persona is drawn beside it yet — nobody has
## one server-side until US-0078 — so this does not complete US-0073's portrait.
func _draw_identified() -> void:
	draw_arc(Vector2(90.0, 112.0), 32.0, 0.0, TAU, 48, palette.text_dim, FRAME_WIDTH, true)
	draw_polyline(
		PackedVector2Array([Vector2(74.0, 112.0), Vector2(86.0, 124.0), Vector2(108.0, 100.0)]),
		palette.text,
		3.0,
		true
	)
	_caption(Strings.get_text(&"ui.contract.identified"), 196.0, LABEL_SIZE)
