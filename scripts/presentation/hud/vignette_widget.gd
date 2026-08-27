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
const REACH := 0.22
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


## Concentric inset frames, each a little more transparent than the last. Cheap,
## needs no shader, and the falloff is what stops it reading as a black border.
func _draw() -> void:
	if _alpha <= 0.001:
		return
	var reach := minf(size.x, size.y) * REACH
	for i: int in BANDS:
		var t := float(i) / float(BANDS)
		var inset := reach * t
		var band := Palette.with_alpha(
			palette.vignette, palette.vignette.a * _alpha * (1.0 - t) * 0.16
		)
		draw_rect(
			Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0),
			band,
			false,
			reach / float(BANDS) + 1.0
		)
