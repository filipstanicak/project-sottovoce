## **EVERY COLOUR THE HUD DRAWS.** UI_UX_SPEC §7, US-0073. CLIENT ONLY.
##
## §7's rule is one sentence — *"all colour comes from a `Palette` resource
## injected into every widget. **No widget names a colour literal**"* — and it
## named `test_no_colour_literals.gd` as the enforcement. **Neither the resource
## nor the guard existed**, which is trap 14's shape in a bible section, and it is
## why `CompassWidget` shipped four literals in US-0072. Both exist now.
##
## **THE POINT IS NOT TIDINESS, IT IS THAT A PALETTE CAN BE SWAPPED.** §7.1 needs
## four of these — one trichromatic, two red-green, one monochrome — and the
## monochrome one is the *verification* palette for the other three. A widget that
## names a literal cannot be verified against any of them, because there is nothing
## to swap.
##
## **ONLY `DEFAULT` IS AUTHORED HERE, AND THAT IS DELIBERATE.** The other three are
## `US-0083`'s, at M6, and they are a **data** question rather than a structural
## one: the seam is what is expensive to add late, and the seam is what this is.
class_name Palette
extends Resource

## Tier shapes and words. `neutral` carries Anonymous, which is the absence of a
## signal rather than a signal of its own.
@export var neutral: Color = Color(0.86, 0.88, 0.90)
@export var noticed: Color = Color(0.93, 0.78, 0.42)
@export var exposed: Color = Color(0.90, 0.42, 0.34)

## The Compass. **All four are near-neutral on purpose** — §7.3: the Compass
## encodes nothing in hue, so there is nothing in it to be colourblind to, and
## `test_compass_invents_nothing.gd` asserts the saturation stays low.
@export var compass_cone: Color = Color(0.86, 0.88, 0.90, 0.42)
@export var compass_ring: Color = Color(0.94, 0.95, 0.96)
@export var compass_lock: Color = Color(0.98, 0.98, 0.98, 0.85)
@export var compass_dot: Color = Color(0.90, 0.91, 0.93, 0.75)

## The crosshair. **Kill and stun differ in shape first** (§6: a bracket pair, not
## just a colour), so these two exist to reinforce a distinction that is already
## legible without them.
@export var crosshair: Color = Color(0.92, 0.93, 0.95, 0.80)
@export var crosshair_kill: Color = Color(0.96, 0.96, 0.97)
@export var crosshair_stun: Color = Color(0.72, 0.88, 0.86)

## The score feed. **A penalty differs in plate first** (UI_UX_SPEC §5.2: the one
## negative event must never read as a smaller positive one), so these two exist to
## reinforce a distinction the plate already carries — the same relationship the
## crosshair's two colours have with its two shapes.
@export var score: Color = Color(0.95, 0.95, 0.96)
@export var score_penalty: Color = Color(0.91, 0.55, 0.44)

## Text and plates.
@export var text: Color = Color(0.93, 0.94, 0.95)
@export var text_dim: Color = Color(0.93, 0.94, 0.95, 0.62)
@export var plate: Color = Color(0.05, 0.06, 0.07, 0.45)

## The Exposed vignette. §4.2: the only full-screen effect in the game, and
## **deliberately ugly** — it is the visual language of failure.
##
## **THE ALPHA IS THE WHOLE TUNING AND IT SHIPPED AT 1.0 BY OMISSION.** A colour
## written with three channels defaults to opaque, so the first build tinted the
## entire frame red rather than darkening its edges — *deliberately ugly* means
## oppressive, not *the screen is broken*. **Found by looking at it.**
@export var vignette: Color = Color(0.62, 0.16, 0.12, 0.5)


## The tier's colour. **Shape and word carry the same information** (§4), so this
## is the third of three channels rather than the only one — which is what lets
## the monochrome palette collapse all three of these to one value and still work.
func for_tier(tier: int) -> Color:
	if tier >= SuspicionMath.Tier.EXPOSED:
		return exposed
	if tier >= SuspicionMath.Tier.NOTICED:
		return noticed
	return neutral


## One of the palette's colours at a different alpha. **Lives here rather than in
## each widget**: two widgets needed it, and a `Color(x.r, x.g, x.b, a)` in a
## widget is exactly the shape `test_no_colour_literals.gd` forbids — even though
## it names no channel of its own, a reader cannot tell it from a real literal at
## a glance, and neither can the guard.
static func with_alpha(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, alpha)


## The shipped default, for a widget standing up without one. **Never null**: a
## widget that had to branch on whether it has colours would grow a second,
## unpalettable code path, which is exactly what §7 forbids.
static func fallback() -> Palette:
	return Palette.new()
