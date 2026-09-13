## **THE MATCH TIMER: `M:SS`, A THIN BAR, AND `×2` WHEN IT COUNTS.** UI_UX_SPEC
## §1.1 element E, GDD-06 §E, US-0073. CLIENT ONLY.
##
## Top-centre, 120 × 48, because it *"matters intensely for about forty seconds of
## an 8-minute match and should be ignorable for the rest"*. The three things it
## draws are the three things GDD-06 lists and nothing else: the remaining time,
## the bar that fills through the last `TUN-MATCH-FINALPHASE-WARNING`, and the
## phase treatment with a persistent multiplier marker through `FINAL`.
##
## **THE DIGITS ARE 32 px IN A 48 px PLATE.** UI_UX_SPEC §2 lists the timer under
## the 48 px `DISPLAY` scale, and §1.1 gives the element 48 px of height; a 48 px
## glyph and a bar beneath it do not fit in 48 px, so the digits are sized to the
## plate rather than the plate to the digits. Reported here rather than resolved
## silently: the two rows of the spec disagree by the height of the bar.
##
## It reads `MatchVm` and computes nothing of its own — never-do #7 — so the bar's
## fraction and the marker's number are the view model's, and a widget that drew
## the wrong phase would be drawing what it was told.
class_name MatchTimerWidget
extends Control

const TOP := 56.0
const SIZE := Vector2(120.0, 48.0)
const TIME_SIZE := 32
const MARKER_SIZE := 18
const BAR_HEIGHT := 3.0
const BAR_INSET := 8.0

var palette: Palette = null
var vm: MatchVm = null

var _font: Font = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	if vm == null:
		vm = MatchVm.new()
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	custom_minimum_size = SIZE
	offset_left = -SIZE.x * 0.5
	offset_right = SIZE.x * 0.5
	offset_top = TOP
	offset_bottom = TOP + SIZE.y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vm.changed.connect(queue_redraw)
	queue_redraw()


func _exit_tree() -> void:
	if vm != null and vm.changed.is_connected(queue_redraw):
		vm.changed.disconnect(queue_redraw)


func _draw() -> void:
	if not vm.is_shown():
		return
	var plate := palette.timer_final_plate if vm.is_final() else palette.plate
	draw_rect(Rect2(Vector2.ZERO, size), plate, true)
	var clock := Strings.get_text(&"ui.timer.clock") % [vm.minutes(), vm.seconds()]
	var clock_width := _font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, TIME_SIZE).x
	var marker := ""
	var marker_width := 0.0
	if vm.is_final():
		marker = Strings.get_text(&"ui.timer.multiplier") % vm.multiplier_label()
		marker_width = _font.get_string_size(marker, HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_SIZE).x
	var gap := 8.0 if marker != "" else 0.0
	var left := (size.x - clock_width - gap - marker_width) * 0.5
	var baseline := 34.0
	draw_string(
		_font,
		Vector2(left, baseline),
		clock,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		TIME_SIZE,
		palette.text
	)
	if marker != "":
		draw_string(
			_font,
			Vector2(left + clock_width + gap, baseline),
			marker,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			MARKER_SIZE,
			palette.timer_warning
		)
	_draw_bar()


## The thin bar under the digits. **Its track is drawn as well**, for the reason
## the chase ring learned at US-0097: a bar with no track is an arc with a gap, and
## the fraction is not judgeable at a glance.
func _draw_bar() -> void:
	var fraction := vm.warning_fraction()
	if fraction <= 0.0:
		return
	var y := size.y - BAR_INSET
	var track := Rect2(BAR_INSET, y, size.x - BAR_INSET * 2.0, BAR_HEIGHT)
	draw_rect(track, Palette.with_alpha(palette.text_dim, 0.35), true)
	draw_rect(
		Rect2(track.position, Vector2(track.size.x * fraction, BAR_HEIGHT)),
		palette.timer_warning,
		true
	)
