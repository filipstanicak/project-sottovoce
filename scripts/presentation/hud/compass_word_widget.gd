## **THE ONE WORD THE COMPASS SAYS: UP OR DOWN.** US-0105, UI_UX_SPEC §3.1. CLIENT
## ONLY.
##
## **A WIDGET OF ITS OWN SO `CompassWidget` KEEPS DRAWING NO TEXT AT ALL.**
## `test_compass_invents_nothing.gd` holds the Compass to that as the strongest form
## of *never a number*: with no `draw_string` there is nothing to hand a distance
## to. The reference writes *up* and *down* at its ring's centre, so the word lives
## here, at the same centre (`CompassWidget.place`), and `word_for` is the only
## source of what it can draw: one of two string-table words, or nothing.
class_name CompassWordWidget
extends Control

## 18 px at the 1080 reference: 13 was unreadable at 720p when it was looked at.
const WORD_SIZE := 18

var vm: CompassVm = null
var palette: Palette = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	CompassWidget.place(self, CompassWidget.DIAMETER)


func _process(_delta: float) -> void:
	queue_redraw()


## The word for a `CompassBoard.Vertical`, upper-cased, or empty for level.
static func word_for(vertical: int) -> String:
	match vertical:
		CompassBoard.Vertical.UP:
			return Strings.get_text(&"ui.compass.up").to_upper()
		CompassBoard.Vertical.DOWN:
			return Strings.get_text(&"ui.compass.down").to_upper()
	return ""


## Upright, on the side away from `CompassWidget`'s chevron, so the two never
## overlap: below it for up, above it for down.
func _draw() -> void:
	if vm == null or not vm.has_contract():
		return
	var word := word_for(vm.vertical)
	if word.is_empty():
		return
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SIZE).x
	var up := vm.vertical == CompassBoard.Vertical.UP
	var baseline := size * 0.5 + Vector2(-width * 0.5, 9.0 if up else 2.0)
	draw_string(
		font, baseline, word, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SIZE, palette.compass_ring
	)
