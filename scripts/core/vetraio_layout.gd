## MAP-VETRAIO as DATA. The schematic in GDD-05 §2.1, transcribed once.
##
## Pure Core, so `test_map_metrics`, `test_map_widths` and `test_map_dead_ends`
## can check the map WITHOUT loading a scene. The generator builds geometry from
## this table and the tests check this table, so they cannot disagree — and a
## dimension only has to be right in one place.
##
## EVERY HEIGHT HERE COMES FROM THE METRICS BIBLE (GDD-05 §4.1) AND AVOIDS ITS
## BOUNDARY BANDS. A surface at 1.10 m resolves as vault or mantle depending on
## sub-centimetre position, which reads to a player as the game being broken.
class_name VetraioLayout
extends RefCounted

const MAP_SIZE := 120.0
const STREET_Y := 0.0
const BALCONY_Y := 3.5
const ROOF_Y := 8.5

## Traversal heights, GDD-05 §4.1. Named so a reader sees the intent, not a float.
##
## CORRECTED 2026-08-05. §4.1 listed street→balcony 4.5 and balcony→roof 4.0, but
## a 4.0 m façade is also a 4.0 m DROP coming down, and 3.9–4.1 is the table's own
## stagger boundary — the stagger would fire or not by sub-centimetre position.
## Balcony moved to 3.5, so the drops are 3.5 (clearly safe) and 5.0 (clearly
## staggering). street→roof stays 8.5 and still clears the 8.9–9.1 climb band.
const H_VAULT := 0.9
const H_MANTLE := 1.8
## 1.0, not the 1.1 GDD-05 §4.1 listed: 1.05-1.15 is that table's own
## vault/mantle band, and the row says a rail must resolve as a VAULT. 1.0 is the
## smallest change that clears the band while keeping a rail visibly taller than
## a 0.9 m stall counter, which is the distinction the table was drawing.
const H_BALCONY_RAIL := 1.0
const H_FACADE_STREET_TO_BALCONY := 3.5
const H_FACADE_BALCONY_TO_ROOF := 5.0
const H_FACADE_STREET_TO_ROOF := 8.5

## Bands geometry must never occupy, GDD-05 §4.1. `test_map_metrics` scans for
## any traversable surface inside one and fails the build.
const BOUNDARY_BANDS: Array[Vector2] = [
	Vector2(1.05, 1.15),  # vault / mantle
	Vector2(2.25, 2.35),  # mantle / climb
	Vector2(8.9, 9.1),  # climb-height limit
	Vector2(3.0, 3.4),  # jump / no-jump (gaps)
	Vector2(3.9, 4.1),  # drop stagger
]

## Circulation minima, GDD-05 §4.2.
## --- NAVMESH BAKE PARAMETERS. TDD-08 §7. ---
##
## **DELIBERATELY NOT TUNABLES, AND THE REASON IS NOT LAZINESS.** TDD-08 §7 says
## the navmesh is baked from static geometry and **never rebaked at runtime**. A
## `TUN-` value that did nothing until somebody re-ran a tool would be worse than
## a constant: never-do #1 exists so that changing a number changes the game, and
## a tunable that silently does not is the exact failure it guards against.
##
## They live here because this file is the map's single source, and the navmesh
## is a property of the baked map.
const NAV_AGENT_RADIUS := 0.4

## 1.8 m — the NPC capsule, and the player's.
const NAV_AGENT_HEIGHT := 1.8

## 35°, above the 30° stair angle so stairs are navigable and roofs are not.
const NAV_MAX_SLOPE := 35.0

## **HOW HIGH A STEP A CIVILIAN CAN TAKE, AND THE REASON MARKET STALLS ARE NOT
## FURNITURE.** Godot's default is 0.9, which is exactly the height of a stall
## counter — so the baker connected every stall top to the street and the crowd
## treated them as walkable. Measured, not reasoned about: an NPC ended a run
## standing on StallA at (38.3, 0.90, 18.6).
##
## An NPC standing on a market stall is wrong twice over. It reads as a broken
## civilian, and 0.9–1.1 m is the **vault** band — the stalls are the things a
## player vaults, and a crowd that could stand on them would quietly make being
## up there ordinary. Two cells, so Recast's quantisation leaves it alone.
const NAV_MAX_CLIMB := 0.4

## The band the navmesh may be baked from: the street stratum and nothing above
## it. **This is the same design fact as `TUN-SUSPICION-GAIN-ROOF`** — NPCs cannot
## reach roofs or balconies, which is precisely why standing there costs
## anonymity. Baking a roof would quietly refund that cost.
const NAV_BAKE_FLOOR := -2.0
const NAV_BAKE_CEILING := 2.5

## **THE VOXEL SIZE THE BAKER ACTUALLY WORKS IN, AND IT MUST DIVIDE THE AGENT
## DIMENSIONS EXACTLY.** Recast quantises `agent_radius` and `agent_height` to
## whole cells and **ceils** them, so at Godot's default 0.25 the 0.4 m radius
## bakes as 0.5 and the 1.8 m height as 2.0 — the mesh would not be the mesh
## TDD-08 §7 specifies, and nothing but a warning would say so.
##
## 0.2 divides both: 0.4 / 0.2 = 2 cells, 1.8 / 0.2 = 9. Finer cells cost bake
## time and polygons, which is a build-time cost and therefore the cheap side of
## the trade.
const NAV_CELL_SIZE := 0.2
const NAV_CELL_HEIGHT := 0.2

const MIN_ALLEY_WIDTH := 2.6
const ALLEY_MOUTH_RANGE := Vector2(2.2, 2.8)
const ARCADE_SPAN_RANGE := Vector2(3.5, 4.5)
const MAIN_STREET_RANGE := Vector2(6.0, 8.0)
const BRIDGE_WIDTH := 2.4
const MAX_DEAD_END := 8.0
const MIN_LOGGIA_CEILING := 3.2

## Solid blocks: [name, x, z, size_x, size_z, height, material].
## Positions are the block's MINIMUM corner, from the §2.1 schematic.
const BLOCKS: Array = [
	["FornaceRow", 0.0, 0.0, 30.0, 30.0, H_FACADE_STREET_TO_ROOF, "MAT-CLIMB"],
	["CampanileBlock", 90.0, 0.0, 30.0, 30.0, H_FACADE_STREET_TO_ROOF, "MAT-CLIMB"],
	["Campanile", 100.0, 8.0, 8.0, 8.0, 22.0, "MAT-CLIMB"],
	["VicoloWestWall", 0.0, 66.0, 12.0, 30.0, H_FACADE_STREET_TO_ROOF, "MAT-GREY-WALL"],
	["FondacoWest", 0.0, 99.0, 42.0, 21.0, H_FACADE_STREET_TO_ROOF, "MAT-CLIMB"],
	["FondacoEast", 54.0, 99.0, 66.0, 21.0, H_FACADE_STREET_TO_ROOF, "MAT-CLIMB"],
	["MercatoNorthWall", 90.0, 60.0, 30.0, 6.0, H_MANTLE, "MAT-GREY-WALL"],
]

## Walkable surfaces: [name, x, z, size_x, size_z, y, material].
const FLOORS: Array = [
	["PiazzaDelVetro", 30.0, 0.0, 60.0, 30.0, STREET_Y, "MAT-GREY-FLOOR"],
	["ViaDelleLampe", 0.0, 30.0, 30.0, 36.0, STREET_Y, "MAT-GREY-FLOOR"],
	["Loggia", 30.0, 36.0, 90.0, 18.0, STREET_Y, "MAT-GREY-FLOOR"],
	["PiazzaSecca", 34.0, 60.0, 56.0, 30.0, STREET_Y, "MAT-GREY-FLOOR"],
	["MercatoPiccolo", 90.0, 66.0, 30.0, 30.0, STREET_Y, "MAT-GREY-FLOOR"],
	["VicoloStretto", 12.0, 66.0, 22.0, 24.0, STREET_Y, "MAT-GREY-FLOOR"],
	["PonteCorto", 46.0, 90.0, BRIDGE_WIDTH, 9.0, STREET_Y, "MAT-GREY-FLOOR"],
	["FondacoStreet", 0.0, 96.0, 120.0, 3.0, STREET_Y, "MAT-GREY-FLOOR"],
	["EastStreet", 90.0, 30.0, 30.0, 6.0, STREET_Y, "MAT-GREY-FLOOR"],
	# **THE TWO ALLEY MOUTHS GDD-05 §2.1 HAS ALWAYS DRAWN.** Its schematic marks the
	# piazza's south edge at z = 30 as a wall pierced by two openings (the `╥` marks)
	# with matching arcade openings into the Loggia below them. **Neither was ever
	# built**, so nothing bridged z 30-36 for x 30-90 and the district's largest and
	# densest space was a **disconnected navmesh island**: `PiazzaDelVetro reaches 0
	# of 8` other streets, 24 of 67 idle anchors unreachable, and CIRC-A and CIRC-D
	# both routed through a piazza no civilian could walk to.
	#
	# **THE EAST MOUTH'S POSITION IS DERIVED, NOT CHOSEN.** `CIRC-A`'s existing route
	# crosses z = 30 at x = 69.1 on its way from (74, 22) to (60, 45) — the procession
	# was authored walking through an opening that was never cut, so the route says
	# where it belongs. The west mouth is the piazza's western quarter point, which is
	# also where §2.1 draws it.
	[
		"MouthWest",
		45.0 - MIN_ALLEY_WIDTH * 0.5,
		30.0,
		MIN_ALLEY_WIDTH,
		6.0,
		STREET_Y,
		"MAT-GREY-FLOOR"
	],
	[
		"MouthEast",
		69.0 - MIN_ALLEY_WIDTH * 0.5,
		30.0,
		MIN_ALLEY_WIDTH,
		6.0,
		STREET_Y,
		"MAT-GREY-FLOOR"
	],
	["LoggiaBalcony", 30.0, 36.0, 90.0, 4.0, BALCONY_Y, "MAT-GREY-FLOOR"],
]

## Vaultable stall counters in the market. All at H_VAULT, GDD-05 §4.1.
const STALLS: Array = [
	["StallA", 36.0, 18.0, 6.0, 2.0],
	["StallB", 48.0, 18.0, 6.0, 2.0],
	["StallC", 60.0, 18.0, 6.0, 2.0],
	["StallD", 72.0, 18.0, 6.0, 2.0],
	["StallE", 96.0, 72.0, 6.0, 2.0],
	["StallF", 96.0, 84.0, 6.0, 2.0],
]

## The canal. Impassable water, 4 m wide, excluded from the navmesh.
const CANAL := Rect2(0.0, 92.0, 120.0, 4.0)

## The five concealment props, GDD-05 §2.4. Each has a positional weakness.
const BLEND_PROPS: Array = [
	["H1", 14.0, 18.0],  # Fornace Row — cooling well, next to the loudest area
	["H2", 14.0, 52.0],  # Via delle Lampe — hay cart, high traffic
	["H3", 62.0, 84.0],  # Piazza Secca — dry fountain, inside the danger zone
	["H4", 104.0, 78.0],  # Mercato Piccolo — wardrobe, safest but furthest
	["H5", 78.0, 108.0],  # Fondaco — crates, across the canal
]

## TUN-SPAWN-POINT-COUNT points, GDD-05 §2.7. All street-level, none in Piazza
## Secca — you never begin a life already accruing suspicion.
## **THREE OF THESE STOOD OVER NOTHING UNTIL 2026-08-13.** S3, S4 and S6 were at
## z 106, z 106 and (104, 26) — past the northern edge of `FondacoStreet` and
## outside every floor rectangle in the district. A pawn placed there falls.
## Nobody had hit it because `LocalPawnDriver.spawn_index` is 0 and spawn
## SELECTION is US-0062, so only S1 has ever been used.
##
## GDD-05 §2.7 names where they belong — Fondaco west, Fondaco east, Campanile
## base, all street stratum — and the table below now agrees with it. Rule 1,
## thirty metres to the nearest other spawn, is satisfied and arithmetic; **rules
## 4 and 6 (circuit proximity and spawn-to-spawn sightlines) were NOT re-derived**
## and are owed a level pass.
const SPAWNS: Array = [
	["S1", 12.0, 36.0],
	["S2", 20.0, 70.0],
	["S3", 6.0, 97.5],
	["S4", 114.0, 97.5],
	["S5", 100.0, 70.0],
	["S6", 88.0, 14.0],
]

## The four blend-group circuits, GDD-05 §2.5. Closed loops; no circuit enters
## Piazza Secca, because the empty plaza staying empty is its entire function.
const CIRCUITS: Array = [
	[
		"CIRC-A",
		58.0,
		[
			Vector2(40.0, 15.0),
			Vector2(60.0, 15.0),
			Vector2(74.0, 22.0),
			Vector2(60.0, 45.0),
			Vector2(40.0, 45.0),
			Vector2(16.0, 44.0),
			Vector2(14.0, 34.0),
			Vector2(32.0, 16.0),
		]
	],
	[
		"CIRC-B",
		71.0,
		[
			Vector2(36.0, 45.0),
			Vector2(56.0, 45.0),
			Vector2(76.0, 45.0),
			Vector2(98.0, 46.0),
			Vector2(104.0, 72.0),
			Vector2(104.0, 86.0),
			Vector2(98.0, 60.0),
			Vector2(76.0, 47.0),
			Vector2(56.0, 47.0),
		]
	],
	[
		"CIRC-C",
		74.0,
		[
			Vector2(100.0, 80.0),
			Vector2(106.0, 60.0),
			Vector2(104.0, 34.0),
			Vector2(112.0, 60.0),
			Vector2(110.0, 97.0),
			Vector2(80.0, 97.0),
			Vector2(47.0, 97.0),
			Vector2(47.0, 92.0),
			Vector2(60.0, 91.0),
			Vector2(90.0, 91.0),
		]
	],
	[
		"CIRC-D",
		66.0,
		[
			Vector2(44.0, 12.0),
			Vector2(28.0, 12.0),
			Vector2(14.0, 20.0),
			Vector2(14.0, 40.0),
			Vector2(20.0, 68.0),
			Vector2(24.0, 84.0),
			Vector2(18.0, 60.0),
			Vector2(22.0, 40.0),
			Vector2(34.0, 14.0),
		]
	],
]

## Density zones, GDD-05 §3. [name, x, z, size_x, size_z, density, is_theatre]
##
## DENSE MEANS THE STALL ROWS, NOT WHOLE PIAZZAS. GDD-05 §4.4's 1-anchor-per-12 m²
## applied to the full piazza footprints yields 364 anchors, but the crowd budget
## is TUN-CROWD-COUNT-DEFAULT-6P 78 NPCs, of which 16 walk circuits — so 17 % of
## anchors could ever be occupied and a "dense" zone would deliver ~1.6 NPCs
## within 6 m instead of the 7-11 §3 promises.
##
## Resolved by zoning only what is genuinely dense. The open piazza floor is then
## what it visually is: space you cross, not cover you hide in. Anchor total is
## now ~66 against ~62 idle NPCs, so the authored density is actually reachable
## rather than aspirational.
const ZONES: Array = [
	["VetroStallRow", 36.0, 14.0, 42.0, 6.0, MapZone.Density.DENSE, false],
	["MercatoStallRow", 94.0, 70.0, 12.0, 6.0, MapZone.Density.DENSE, false],
	["LoggiaSpine", 30.0, 40.0, 60.0, 6.0, MapZone.Density.MEDIUM, false],
	["ViaDelleLampe", 10.0, 30.0, 12.0, 36.0, MapZone.Density.MEDIUM, false],
	["VicoloStretto", 12.0, 66.0, 22.0, 24.0, MapZone.Density.LOW, false],
	["Fondaco", 0.0, 96.0, 120.0, 3.0, MapZone.Density.LOW, false],
	["PiazzaSecca", 34.0, 60.0, 56.0, 30.0, MapZone.Density.LOW, true],
]

## The two theatre spaces, GDD-05 §5.3.
const THEATRES: Array = [
	["PiazzaSecca", 34.0, 60.0, 56.0, 30.0],
	["PonteCortoApproaches", 36.0, 76.0, 24.0, 34.0],
]


## True when `height` sits inside a boundary band and is therefore unbuildable.
static func in_boundary_band(height: float) -> bool:
	for band: Vector2 in BOUNDARY_BANDS:
		if height >= band.x and height <= band.y:
			return true
	return false


## Every traversable height the layout declares, for the metrics guard.
static func traversable_heights() -> Array:
	var out: Array = []
	for b: Array in BLOCKS:
		out.append([b[0], float(b[5])])
	for s: Array in STALLS:
		out.append([s[0], H_VAULT])
	out.append(["BalconyRail", H_BALCONY_RAIL])
	out.append(["FacadeStreetToBalcony", H_FACADE_STREET_TO_BALCONY])
	out.append(["FacadeBalconyToRoof", H_FACADE_BALCONY_TO_ROOF])
	return out
