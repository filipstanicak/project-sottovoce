## **WHAT DID I JUST GET PAID FOR?** GDD-06 §2.2 D, UI_UX_SPEC §5, US-0074.
## CLIENT ONLY.
##
## **RIGHT SIDE, ABOVE CENTRE, AND THE PLACEMENT IS THE REQUIREMENT.** GDD-06 §3.2:
## it must be readable *without being looked at* — a player who has to look at the
## HUD to learn is a player who is not watching the crowd. Everything here serves
## legibility in the periphery rather than at the fovea.
##
## **THE DIGITS ARE TABULAR, AND THIS DRAWS THEM ONE BY ONE TO GUARANTEE IT.**
## `font-variant-numeric` has no Godot equivalent and the fallback font is not
## tabular, so a `+50` becoming a `+200` would shift every glyph beside it.
## Differing widths produce horizontal jitter, jitter in peripheral vision reads as
## *motion*, and motion pulls the eye — which is the one thing this element must
## not do. Each digit advances by the widest digit's width instead.
##
## **IT HOLDS NO RULE, ONLY A LAYOUT.** It does not know what a bonus is worth,
## when one expires, or which arrive together; `ScoreFeedVm` owns all three. What
## it decides is where a line sits and how it fades.
class_name ScoreFeedWidget
extends Control

## From the right edge and above the vertical centre. Above rather than below
## because the crosshair, the ability slots and the tier block are all below it,
## and the feed must never be the thing under a player's aim.
const MARGIN := Vector2(52.0, 40.0)
## **THE BLOCK IS TALLER THAN ITS CONTENT, AND THE FIRST BUILD WAS NOT.** At 34 px
## a block was exactly as tall as the value plus the name, so consecutive blocks
## touched and four bonuses read as one eight-row ladder — and the penalty plate,
## which is padded, drew straight over the line above it. Found by looking at it.
const BLOCK := Vector2(132.0, 48.0)

## Value baseline, then name baseline, measured from the block's top. The plate is
## derived from the same two numbers rather than given its own, so it cannot grow
## past the block that owns it.
const VALUE_BASE := 19.0
const NAME_GAP := 15.0

const VALUE_SIZE := 19
const NAME_SIZE := 13

## UI_UX_SPEC §5: entry is *slide 16 px + fade over 0.15 s*, exit is *fade only
## over 0.3 s*. The slide is inward from the right, so a new line enters from the
## edge it is anchored to rather than across the screen.
const ENTER_TIME := 0.15
const EXIT_TIME := 0.3
const SLIDE := 16.0

## §5.2 prices a penalty as *"different plate, different weight"* — **which says
## every line has a plate**, and the first build gave only the penalty one. Looking
## at it settled the question: white text over the district's pale sky is at the
## edge of legible at the fovea and gone in the periphery, and this element's whole
## requirement is to be read without being looked at.
const PLATE_PAD := Vector2(9.0, 4.0)

## The warm plate a penalty gets instead of the neutral one. Alpha rather than a
## fifth palette entry, so a colourblind palette that changes `score_penalty`
## changes both channels at once.
const PENALTY_PLATE_ALPHA := 0.34

var palette: Palette = null
var vm: ScoreFeedVm = null

var _font: Font = null
var _digit: float = 0.0


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	_font = ThemeDB.fallback_font
	_digit = _widest_digit()
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vm != null:
		vm.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if vm == null:
		return
	vm.update(delta)
	queue_redraw()


func _draw() -> void:
	if vm == null or _font == null:
		return
	var right := size.x - MARGIN.x
	var top := size.y * 0.5 - MARGIN.y - BLOCK.y * float(vm.lines.size())
	for i: int in vm.lines.size():
		_draw_line(vm.lines[i], right, top + BLOCK.y * float(i))


## One block: the value right-aligned against the panel edge, the name below-left
## of it and smaller. **Both documents are satisfied by this and they do not agree
## in as many words** — GDD-06 §3.2 writes the content as `+150 Patient` while
## UI_UX_SPEC §5 gives the layout as *"value right-aligned (tabular), name
## left-aligned below"*. The value leads and the name sits under it, which is the
## layout the specific document asks for carrying the pair the other one names.
func _draw_line(line: ScoreFeedVm.Line, right: float, top: float) -> void:
	var age := line.age(vm.now())
	var fade := _alpha(line, age)
	if fade <= 0.0:
		return
	var slide := SLIDE * (1.0 - minf(age / ENTER_TIME, 1.0))
	var name_text := Strings.get_text(line.key)
	var value := _value_of(line)
	var left := right - BLOCK.x + slide
	var colour := palette.score_penalty if line.penalty else palette.score
	_draw_plate(left, top, _plate_of(line, fade))
	_draw_value(value, right + slide, top + VALUE_BASE, Palette.with_alpha(colour, fade))
	draw_string(
		_font,
		Vector2(left, top + VALUE_BASE + NAME_GAP),
		name_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		NAME_SIZE,
		Palette.with_alpha(palette.text, fade)
	)


## **THE NAME IS DRAWN AT FULL STRENGTH AND THE FIRST BUILD DIMMED IT.** GDD-06
## §3.2: *"named, not numeric — the name IS the lesson"*, and a lesson set in the
## dim colour the tier widget uses for a secondary list is the wrong way round. The
## value stays dominant by **size**, which is a channel the palette cannot undo.
func _plate_of(line: ScoreFeedVm.Line, fade: float) -> Color:
	if line.penalty:
		return Palette.with_alpha(palette.score_penalty, PENALTY_PLATE_ALPHA * fade)
	return Palette.with_alpha(palette.plate, palette.plate.a * fade)


## **RIGHT-ALIGNED AND TABULAR, WHICH IS ONE OPERATION HERE AND TWO ANYWHERE
## ELSE.** Walking backwards from the right edge by a fixed advance gives both at
## once, so the sign and every digit sit on a column that does not move when the
## value changes width.
func _draw_value(text: String, right: float, baseline: float, colour: Color) -> void:
	var at := right
	for i: int in range(text.length() - 1, -1, -1):
		var glyph := text[i]
		at -= _digit
		draw_string(
			_font,
			Vector2(at, baseline),
			glyph,
			HORIZONTAL_ALIGNMENT_CENTER,
			_digit,
			VALUE_SIZE,
			colour
		)


func _draw_plate(left: float, top: float, colour: Color) -> void:
	var content := Vector2(BLOCK.x, VALUE_BASE + NAME_GAP)
	draw_rect(Rect2(Vector2(left, top) - PLATE_PAD, content + PLATE_PAD * 2.0), colour, true)


## **A ZERO IS SIGNED `+`, NOT LEFT BARE.** `SCORE-RECKLESS` pays exactly zero and
## still draws (ADR-0013 neutralised the charge and kept the line, because *you
## were seen* is the half that teaches). A bare `0` beside four `+200`s reads as a
## bonus that failed rather than as a bonus that is a marker.
func _value_of(line: ScoreFeedVm.Line) -> String:
	return ("%d" % line.points) if line.points < 0 else ("+%d" % line.points)


## In over `ENTER_TIME`, out over `EXIT_TIME`, full in between.
func _alpha(line: ScoreFeedVm.Line, age: float) -> float:
	var left := line.dies_at - line.show_at - age
	return clampf(minf(age / ENTER_TIME, left / EXIT_TIME), 0.0, 1.0)


## The widest digit in this font at this size, measured once. Includes `+` and `-`
## so a sign occupies the same column a digit would.
func _widest_digit() -> float:
	var widest := 0.0
	for glyph: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "-"]:
		widest = maxf(
			widest, _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_SIZE).x
		)
	return widest
