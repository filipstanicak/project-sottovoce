## One density zone on a map. GDD-05 §3.
##
## Density is the game's substrate (CLAUDE.md never-do #14), so a zone is not
## decoration — it is the contract that says how many NPCs a player can expect to
## hide among here. `SYS-CROWD` reads these to place idle anchors.
class_name MapZone
extends Resource

## GDD-05 §4.4: anchors per m², which produces the NPC counts in §3.
enum Density { LOW, MEDIUM, DENSE }

## Metres² per idle anchor, indexed by Density. From GDD-05 §4.4.
const AREA_PER_ANCHOR: Array[float] = [70.0, 30.0, 12.0]

@export var zone_name: StringName = &""

## World-space bounds. Y is the stratum the zone occupies.
@export var bounds: AABB = AABB()

@export var density: Density = Density.MEDIUM

## True for Piazza Secca. A theatre space is deliberately empty — an audience
## needs an unobstructed stage, and the emptiness is the mechanic.
@export var is_theatre: bool = false


## How many idle anchors this zone's area implies.
func expected_anchors() -> int:
	var area := bounds.size.x * bounds.size.z
	return int(round(area / AREA_PER_ANCHOR[density]))
