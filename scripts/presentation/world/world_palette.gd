## **EVERY COLOUR THE DISTRICT IS BUILT IN.** ART_BIBLE §3, ADR-0026. CLIENT ONLY.
##
## The colour-language law gives hue three meanings — persona identity, suspicion
## and ability tells — and puts everything else in a *desaturated warm-neutral
## range: stone, plaster, terracotta, weathered timber, dull brass*. This is that
## range, in one file, for the same reason `Palette` holds the HUD's: a colour
## named beside the thing it paints cannot be checked against the four persona
## hues, and `test_world_palette_keeps_the_reserved_hues.gd` checks every one here.
##
## **VALUE CARRIES THE DISTRICT, NOT HUE** (§4, *value over hue*): warm plaster
## against cool coursed stone, light ground against dark water. The cool stone is
## also the climbing language — every climbable facade is coursed stone, every
## other wall is plaster — which is what `MAT-CLIMB`'s blue said in the greybox.
class_name WorldPalette
extends Resource

## No tint: a part that takes its material's own colour.
const PLAIN := Color(1.0, 1.0, 1.0)
## No light: a window with nobody home.
const DARK := Color(0.0, 0.0, 0.0)

## Plaster, one per building by its name. All warm, all pale, none saturated.
@export var plasters: Array[Color] = [
	Color(0.82, 0.76, 0.66),
	Color(0.80, 0.70, 0.55),
	Color(0.78, 0.62, 0.54),
	Color(0.76, 0.74, 0.69),
	Color(0.70, 0.62, 0.52),
	Color(0.84, 0.80, 0.72),
	Color(0.74, 0.58, 0.48),
]
## What shows where the plaster has fallen.
@export var brick: Color = Color(0.56, 0.40, 0.34)
## The coursed stone of a climbable facade, and its joints.
@export var climb_stone: Color = Color(0.60, 0.62, 0.66)
@export var climb_joint: Color = Color(0.33, 0.34, 0.37)
## Trim: plinths, string courses, cornices, window surrounds, copings.
@export var trim: Color = Color(0.76, 0.74, 0.69)
## Quay walls and foundations, darker for standing in water.
@export var quay: Color = Color(0.50, 0.49, 0.47)

## A light grey, by owner decision (2026-10-09), and no lighter: the blend net is
## a white line on this ground and has to stay one in full sun.
@export var ground_a: Color = Color(0.43, 0.42, 0.41)
@export var ground_b: Color = Color(0.50, 0.49, 0.47)
@export var ground_joint: Color = Color(0.30, 0.29, 0.28)
@export var ground_band: Color = Color(0.60, 0.59, 0.56)
@export var board: Color = Color(0.46, 0.38, 0.30)

@export var terrace_tile: Color = Color(0.62, 0.46, 0.39)
@export var terrace_joint: Color = Color(0.40, 0.36, 0.33)
@export var roof_tile: Color = Color(0.64, 0.45, 0.37)

@export var timber: Color = Color(0.44, 0.35, 0.27)
@export var timber_dark: Color = Color(0.29, 0.23, 0.18)
@export var shutter: Color = Color(0.40, 0.41, 0.44)
@export var linen: Color = Color(0.84, 0.81, 0.73)
## The second stripe of an awning, one per stall by its name.
@export var stripes: Array[Color] = [
	Color(0.58, 0.44, 0.39),
	Color(0.46, 0.48, 0.54),
	Color(0.62, 0.58, 0.50),
]
@export var iron: Color = Color(0.20, 0.20, 0.22)
@export var straw: Color = Color(0.74, 0.69, 0.55)
@export var clay: Color = Color(0.60, 0.47, 0.40)
## Leaves in a window box and cypress across the water: dark, and greyer than any
## persona.
@export var foliage: Color = Color(0.22, 0.32, 0.25)

## A window by day, and the light behind the few that are lit. *Warm interiors,
## cool exteriors* (§4): the only warm light in the district is indoors.
@export var glass: Color = Color(0.08, 0.10, 0.13)
@export var window_glow: Color = Color(1.0, 0.76, 0.48)

## Blue-grey, a clear step of hue away from the Vetraio's teal: the canal is the
## largest surface in the district and may not tint toward a persona.
@export var water_deep: Color = Color(0.06, 0.09, 0.13)
@export var water_shallow: Color = Color(0.20, 0.26, 0.34)

@export var sky_zenith: Color = Color(0.16, 0.36, 0.70)
@export var sky_low: Color = Color(0.56, 0.72, 0.90)
@export var sky_horizon: Color = Color(0.86, 0.80, 0.72)
@export var sky_ground: Color = Color(0.62, 0.62, 0.62)
@export var sun_glow: Color = Color(1.0, 0.76, 0.50)
@export var cloud_lit: Color = Color(1.0, 0.94, 0.86)
@export var cloud_shade: Color = Color(0.56, 0.58, 0.68)
@export var sunlight: Color = Color(1.0, 0.92, 0.80)
@export var haze: Color = Color(0.78, 0.76, 0.74)


## Every colour painted on a surface a player stands beside. The sky, the sunlight
## and the window glow are light rather than paint and are not in it.
func surfaces() -> Array[Color]:
	var out: Array[Color] = []
	out.append_array(plasters)
	out.append_array(stripes)
	(
		out
		. append_array(
			[
				brick,
				climb_stone,
				climb_joint,
				trim,
				quay,
				ground_a,
				ground_b,
				ground_joint,
				ground_band,
				board,
				terrace_tile,
				terrace_joint,
				roof_tile,
				timber,
				timber_dark,
				shutter,
				linen,
				iron,
				straw,
				clay,
				foliage,
				glass,
				water_deep,
				water_shallow,
			]
		)
	)
	return out


## The same one of `from` for the same `name`, on every client and every run:
## a building's colour is a property of the building. `String.hash()` is djb2.
static func pick(from: Array[Color], name: String) -> Color:
	return from[name.hash() % from.size()]
