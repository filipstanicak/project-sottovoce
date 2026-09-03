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

## The two pursuit bars (US-0097). **Hue is the third of three channels here**,
## after radius and direction of travel, which is what keeps `ChaseRingWidget`
## readable on §7.1's monochrome verification palette.
##
## The hunt bar takes the Compass's own near-neutral, because it is the remaining
## life of that instrument. The hunted bar takes `noticed`'s amber, because it is a
## threat channel and the HUD already spends that hue on exactly that meaning —
## a second warning colour would be a second thing to learn.
@export var chase_hunt: Color = Color(0.86, 0.88, 0.90, 0.70)
@export var chase_hunted: Color = Color(0.93, 0.78, 0.42, 0.85)

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

## **THE CINDER CLOUD (US-0067, drawn 2026-09-03) — AND THE FIRST ENTRY HERE THAT
## IS NOT THE HUD.** §7's rule is *"all colour comes from a `Palette` resource"*,
## and a second home for colour is the duplicated-rule shape this project keeps
## finding, so a world effect a player must **read** belongs here rather than
## beside itself. The cloud's edge is a gameplay boundary — GDD-04 §3.1 prices the
## counter to this ability as *wait at the cloud's edge* — so §7.1's colourblind
## variants have to be able to move it.
##
## **NEAR-NEUTRAL, LIKE THE COMPASS, BECAUSE ASH ENCODES NOTHING IN HUE.** There is
## nothing here to be colourblind to; the edge is separated from the volume by
## alpha and by being a ring, not by colour.
##
## **THIS IS THE ALPHA OF ONE SHELL, NOT OF THE CLOUD.** `CinderfallView` draws
## `SHELLS` of them, so what a viewer sees through is `CinderfallView.density()` —
## which is the point: a volume is as opaque as the amount of it you are looking
## through, and at the edge that is one layer.
##
## **THE ALPHA SHIPPED AT 0.72 AND THE DISTRICT WAS PERFECTLY READABLE THROUGH IT.**
## Found by looking, as the vignette's own alpha was. `TUN-CINDERFALL-BLOCKS-LOS`
## makes every sight query through this cloud fail, so a translucent one **promises
## less concealment than the rule grants** — and a player who can see straight
## through their own cover learns not to trust it, which costs the ability its
## whole purpose. The drawing is now as opaque as the rule is.
@export var cinderfall: Color = Color(0.26, 0.25, 0.24, 0.72)
@export var cinderfall_edge: Color = Color(0.13, 0.12, 0.12, 1.0)

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
