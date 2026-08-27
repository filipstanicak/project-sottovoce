## **THE ONLY FULL-SCREEN EFFECT IN THE GAME.** UI_UX_SPEC §4.2, US-0073.
##
## Reserved entirely for **Exposed**. §4.2: *"it is the visual language of failure,
## and it is deliberately ugly. Nothing else in the game takes the whole screen."*
##
## **IT IS A SEPARATE NODE FROM THE TIER INDICATOR ON PURPOSE.** They carry the
## same fact and they are not the same kind of thing: one is a glyph in a corner
## that a player reads, the other is the whole screen going wrong at them. Folding
## the second into the first would make "does this widget take the screen" a
## property of a branch rather than of a node, and the next full-screen effect
## somebody wants would be one `if` away.
##
## **IT FADES IN OVER `TUN-UI-DAMAGE-VIGNETTE-TIME` AND OUT AT THE SAME RATE.**
## Instant would read as a rendering fault; slower would let a player cross the
## Exposed threshold and back without the screen having said anything.
class_name VignetteWidget
extends Control

## How far in from each edge the darkness reaches, as a fraction of the shorter
## screen dimension. A frame rather than a wash: the centre 60 % stays clear
## (§1), because the player is looking there.
## **0.18 RATHER THAN 0.22, SO THE CENTRE 60 % STAYS CLEAR.** §1 reserves it for
## the crosshair alone, and two edges at 0.22 leave only 56 % between them — the
## criterion was ticked against a number that missed it by four points.
const REACH := 0.18
const BANDS := 14

var palette: Palette = null

var _target: float = 0.0
var _alpha: float = 0.0


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.suspicion_tier_changed.connect(_on_tier)


func _exit_tree() -> void:
	if EventBus.suspicion_tier_changed.is_connected(_on_tier):
		EventBus.suspicion_tier_changed.disconnect(_on_tier)


func _on_tier(tier: int, _sources: int) -> void:
	_target = 1.0 if tier >= SuspicionMath.Tier.EXPOSED else 0.0


func _process(delta: float) -> void:
	var seconds := maxf(Tuning.ui_audio.damage_vignette_time, 0.01)
	var step := delta / seconds
	var before := _alpha
	_alpha = move_toward(_alpha, _target, step)
	if not is_equal_approx(before, _alpha):
		queue_redraw()


func alpha() -> float:
	return _alpha


## Four edge gradients, one per side, each fading inward to nothing.
##
## **IT WAS CONCENTRIC `draw_rect` OUTLINES AND IT LOOKED LIKE A WIREFRAME.** Each
## stroke landed as a visible line, so the "vignette" read as a stack of nested
## rectangles — §4.2 wants the screen edge going *dark*, and "deliberately ugly"
## means oppressive rather than *looks like a rendering fault*. **Found by looking
## at it.** A gradient per edge is still shader-free and actually fades.
func _draw() -> void:
	if _alpha <= 0.001:
		return
	var reach := minf(size.x, size.y) * REACH
	var peak := palette.vignette.a * _alpha
	var solid := Palette.with_alpha(palette.vignette, peak)
	var clear := Palette.with_alpha(palette.vignette, 0.0)
	_edge(Rect2(0.0, 0.0, size.x, reach), solid, clear, true)
	_edge(Rect2(0.0, size.y - reach, size.x, reach), clear, solid, true)
	_edge(Rect2(0.0, 0.0, reach, size.y), solid, clear, false)
	_edge(Rect2(size.x - reach, 0.0, reach, size.y), clear, solid, false)


## One edge, as a two-triangle strip with per-vertex colour — the cheapest real
## gradient Godot's 2D API offers without a shader or a texture.
func _edge(area: Rect2, from: Color, to: Color, vertical: bool) -> void:
	var a := area.position
	var b := area.position + Vector2(area.size.x, 0.0)
	var c := area.end
	var d := area.position + Vector2(0.0, area.size.y)
	var colours: PackedColorArray = (
		PackedColorArray([from, from, to, to])
		if vertical
		else PackedColorArray([from, to, to, from])
	)
	draw_polygon(PackedVector2Array([a, b, c, d]), colours)
