## **ONE WALKING GROUP AND ITS FORMATION SLOTS.** GDD-03 §4.1.2, TDD-08 §8,
## US-0043. SERVER ONLY, and PURE apart from the circuit it walks.
##
## **THE LAST SLOT IS NEVER GIVEN TO AN NPC.** `TUN-CROWD-GROUP-SIZE` NPCs walk
## in formation and there is always one free position behind them, because
## joinability that depended on recruitment luck would make "there is a group over
## there I can join" a thing a player cannot rely on — and the walking group is
## the *only* blend that lets you travel while gaining anonymity. A blend you
## cannot count on being there is a blend nobody plans around.
##
## **SLOTS ARE A GRID IN THE GROUP'S OWN FRAME**, two files wide, laid out so that
## the closest pair of slots is exactly `TUN-CROWD-GROUP-SPACING` apart. Loose
## enough that a player can step into one without shoving an NPC out of it, tight
## enough that the five of them read as one group rather than as five people
## walking the same way.
class_name WalkingGroup
extends RefCounted

## Nobody. Slots hold an NPC index, and 0 is a real index, so the empty marker
## has to be negative — the same reason `SlotTable` reserves wire slot 0.
const EMPTY := -1

## The route, and how far along it the formation's front slot has walked.
var circuit: CrowdCircuit = null
var distance: float = 0.0

## Slot -> NPC index, or `EMPTY`. Sized `TUN-CROWD-GROUP-SIZE` + 1; the last
## entry stays `EMPTY` forever and belongs to whichever player claims it.
var occupants: PackedInt32Array = PackedInt32Array()

## The peer holding the joinable slot, or 0 for nobody — `SlotTable`'s convention.
var player_peer: int = 0

var _spacing: float = 1.3


func setup(route: CrowdCircuit, npc_slots: int, spacing: float) -> void:
	circuit = route
	_spacing = spacing
	occupants.resize(maxi(npc_slots, 1) + 1)
	occupants.fill(EMPTY)


## Every position in the formation, including the joinable one.
func slot_count() -> int:
	return occupants.size()


## The slot a player may take. Always the last, always free of NPCs.
func joinable_slot() -> int:
	return occupants.size() - 1


## The first empty slot an NPC may be recruited into, or `EMPTY`.
func free_npc_slot() -> int:
	for slot: int in occupants.size() - 1:
		if occupants[slot] == EMPTY:
			return slot
	return EMPTY


func occupy(slot: int, npc: int) -> void:
	if slot >= 0 and slot < occupants.size() - 1:
		occupants[slot] = npc


func release(slot: int) -> void:
	if slot >= 0 and slot < occupants.size():
		occupants[slot] = EMPTY


## Which slot `npc` holds, or `EMPTY`.
func slot_of(npc: int) -> int:
	for slot: int in occupants.size():
		if occupants[slot] == npc:
			return slot
	return EMPTY


func npc_count() -> int:
	var held := 0
	for slot: int in occupants.size():
		if occupants[slot] != EMPTY:
			held += 1
	return held


## Walk the formation `metres` further along its route.
func advance(metres: float) -> void:
	distance += metres


## Where slot `index` is in the world, right now.
##
## The offsets are rotated onto the circuit's heading, so the formation turns
## with the route rather than sliding sideways round corners.
func slot_position(index: int) -> Vector3:
	if circuit == null:
		return Vector3.ZERO
	var origin := circuit.point_at(distance)
	var heading := circuit.heading_at(distance)
	var right := Vector3(heading.z, 0.0, -heading.x)
	var offset := slot_offset(index, _spacing)
	return origin + right * offset.x + heading * offset.y


## Slot `index`'s offset in the group's own frame: `x` across, `y` along, with
## negative `y` meaning *behind* the front.
##
## Two files, filled front to back. **The closest pair of slots is exactly
## `spacing` apart** — asserted rather than eyeballed, because "loose formation at
## 1.3 m" is an acceptance criterion and a layout whose real minimum was 1.84 m
## would satisfy nobody's reading of it.
static func slot_offset(index: int, spacing: float) -> Vector2:
	var column := index % 2
	var row := index / 2
	return Vector2(float(column) * spacing - spacing * 0.5, -float(row) * spacing)
