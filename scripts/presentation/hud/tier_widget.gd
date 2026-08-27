## **AM I VISIBLE, AND WHY?** UI_UX_SPEC §4, US-0073. CLIENT ONLY.
##
## **SHAPE, COLOUR AND WORD SIMULTANEOUSLY** — an open circle, a half-filled
## circle, a filled triangle; neutral, amber, red; `ANONYMOUS`, `NOTICED`,
## `EXPOSED`. Three channels carrying one fact, so the indicator survives the
## monochrome palette and every colourblind one with nothing added.
##
## **AND THE SOURCE LIST IS THE HALF THAT TEACHES.** §4.1: it exists to answer
## *"why am I visible?"* before the player asks. GDD-06 Part 3's failure mode 3 is
## *"suspicion is opaque"* — a player who cannot **attribute** their suspicion
## cannot learn from it, and a total on its own is not attributable. The bitfield
## is `SuspicionSources.of()`'s own output, so what is listed and what is charged
## cannot disagree.
##
## **THE NUMBER APPEARS NOWHERE.** `EventBus.suspicion_value_changed` carries it and
## this widget does not subscribe. A percentage would turn a felt state into an
## arithmetic one, and the player would optimise the number rather than read the
## world.
class_name TierWidget
extends Control

const MARGIN := Vector2(48.0, 40.0)
const GLYPH_RADIUS := 9.0
const GLYPH_WIDTH := 2.0
const WORD_OFFSET := 20.0
const LIST_OFFSET := 20.0
const WORD_SIZE := 15
const LIST_SIZE := 12

## `SuspicionSources` bit -> string key, in the order they are listed. **Order is
## fixed rather than bitfield order** so the line does not reshuffle itself
## between frames as sources come and go, which would make it unreadable exactly
## when it matters most.
const SOURCES: Array = [
	[SuspicionSources.SPRINT, &"ui.source.sprinting"],
	[SuspicionSources.RUN, &"ui.source.running"],
	[SuspicionSources.CLIMB, &"ui.source.climbing"],
	[SuspicionSources.ROOF, &"ui.source.rooftop"],
	[SuspicionSources.OPEN, &"ui.source.alone"],
]

const SEPARATOR := " · "

var palette: Palette = null

var _tier: int = SuspicionMath.Tier.ANONYMOUS
var _sources: int = SuspicionSources.NONE
var _font: Font = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	position = MARGIN
	custom_minimum_size = Vector2(260.0, 64.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.suspicion_tier_changed.connect(_on_tier)


func _exit_tree() -> void:
	if EventBus.suspicion_tier_changed.is_connected(_on_tier):
		EventBus.suspicion_tier_changed.disconnect(_on_tier)


func _on_tier(tier: int, sources: int) -> void:
	_tier = tier
	_sources = sources
	queue_redraw()


func _draw() -> void:
	var colour := palette.for_tier(_tier)
	var centre := Vector2(GLYPH_RADIUS, GLYPH_RADIUS)
	_draw_glyph(centre, colour)
	draw_string(
		_font,
		Vector2(WORD_OFFSET, GLYPH_RADIUS + 5.0),
		_word(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		WORD_SIZE,
		colour
	)
	var listed := _source_line()
	if listed.is_empty():
		return
	draw_string(
		_font,
		Vector2(WORD_OFFSET, GLYPH_RADIUS + 5.0 + LIST_OFFSET),
		listed,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LIST_SIZE,
		palette.text_dim
	)


## `○` open, `◐` half-filled, `▲` filled — drawn rather than typed, so the shape
## channel does not depend on a font having those glyphs.
func _draw_glyph(centre: Vector2, colour: Color) -> void:
	if _tier >= SuspicionMath.Tier.EXPOSED:
		var r := GLYPH_RADIUS
		draw_colored_polygon(
			PackedVector2Array(
				[
					centre + Vector2(0.0, -r),
					centre + Vector2(r * 0.92, r * 0.75),
					centre + Vector2(-r * 0.92, r * 0.75),
				]
			),
			colour
		)
		return
	draw_arc(centre, GLYPH_RADIUS, 0.0, TAU, 32, colour, GLYPH_WIDTH, true)
	if _tier >= SuspicionMath.Tier.NOTICED:
		# The filled half, drawn as a half-disc so "half" is a shape rather than a
		# shade — a shade would collapse into the outline on the monochrome palette.
		var points := PackedVector2Array()
		for i: int in 17:
			var angle := -PI * 0.5 + PI * (float(i) / 16.0)
			points.append(centre + Vector2.from_angle(angle) * GLYPH_RADIUS)
		draw_colored_polygon(points, colour)


func _word() -> String:
	if _tier >= SuspicionMath.Tier.EXPOSED:
		return Strings.get_text(&"ui.tier.exposed").to_upper()
	if _tier >= SuspicionMath.Tier.NOTICED:
		return Strings.get_text(&"ui.tier.noticed").to_upper()
	return Strings.get_text(&"ui.tier.anonymous").to_upper()


## The contributing sources, in the fixed order above. Empty when nothing
## contributes, which is the common case and draws nothing at all.
func _source_line() -> String:
	var parts: PackedStringArray = []
	for row: Array in SOURCES:
		if _sources & int(row[0]) != 0:
			parts.append(Strings.get_text(row[1] as StringName))
	return SEPARATOR.join(parts)
