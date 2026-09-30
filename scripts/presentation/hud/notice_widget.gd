## **ONE LINE ABOVE THE COMPASS RING.** US-0105, UI_UX_SPEC §1.1 I. CLIENT ONLY.
##
## The reference writes its notices centred just above its compass ring — *a new
## pursuer is on you* at about two thirds of the frame's height — so the line sits
## where the eye already goes for the ring. On a plate, like every score-feed line
## (§5.2's finding: white text over the district's pale sky is unreadable in the
## periphery). **It can only draw one of two string-table sentences, or nothing**
## (`text_for`), so no number can reach the screen through it.
class_name NoticeWidget
extends Control

## Where the line's centre sits, as a fraction of the frame's height.
const CENTRE_HEIGHT := 0.66
const TEXT_SIZE := 24
const PLATE_PAD := Vector2(12.0, 6.0)
## Fade-out at the end, seconds: presentation, like the score feed's own.
const FADE := 0.25

var vm: NoticeVm = null
var palette: Palette = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = CENTRE_HEIGHT
	anchor_bottom = CENTRE_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if vm == null:
		return
	vm.advance(delta)
	queue_redraw()


## The sentence for a `NoticeWire.Kind`, or empty for anything else.
static func text_for(kind: int) -> String:
	match kind:
		NoticeWire.Kind.NEW_PURSUER:
			return Strings.get_text(&"ui.notice.new_pursuer")
		NoticeWire.Kind.TOOK_LEAD:
			return Strings.get_text(&"ui.notice.took_lead")
	return ""


func _draw() -> void:
	if vm == null:
		return
	var text := text_for(vm.current())
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE)
	var alpha := clampf(vm.remaining() / FADE, 0.0, 1.0)
	var top_left := Vector2(-extent.x * 0.5, -extent.y * 0.5)
	var plate := Rect2(top_left - PLATE_PAD, extent + PLATE_PAD * 2.0)
	draw_rect(plate, Palette.with_alpha(palette.plate, palette.plate.a * alpha))
	var baseline := top_left + Vector2(0.0, font.get_ascent(TEXT_SIZE))
	var colour := Palette.with_alpha(palette.text, palette.text.a * alpha)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, colour)
