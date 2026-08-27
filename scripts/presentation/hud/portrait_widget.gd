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
## and cannot say *Vetraio*.
##
## **THE HONEST FIX IS A MESH, NOT A FIELD.** Once the lock completes the client
## already knows which body it locked, and the persona is readable from the pawn it
## is drawing — that is US-0046's `PersonaBody` and it needs the lock to name a
## slot. Adding the persona to the wire instead would hand every client its
## contract's identity on the tick the contract is assigned, which is the leak
## `NETWORK_PROTOCOL` §9's checklist line forbids.
class_name PortraitWidget
extends Control

const SIZE := Vector2(84.0, 84.0)
const MARGIN := Vector2(48.0, 48.0)
const FRAME_WIDTH := 1.5
const LABEL_SIZE := 12

var palette: Palette = null

var _revealed: bool = false
var _font: Font = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	custom_minimum_size = SIZE
	offset_left = -(SIZE.x + MARGIN.x)
	offset_right = -MARGIN.x
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
	draw_rect(Rect2(Vector2.ZERO, size), palette.text_dim, false, FRAME_WIDTH)
	if _revealed:
		return
	# **`Unknown` IS A STRING TABLE KEY**, never a literal — never-do #10. The
	# revealed state draws no word at all: it is waiting on a face, and a word
	# saying "revealed" would be the HUD narrating itself.
	var text := Strings.get_text(&"ui.contract.unknown")
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(
		_font,
		Vector2((size.x - width) * 0.5, size.y * 0.5 + 4.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_SIZE,
		palette.text_dim
	)
