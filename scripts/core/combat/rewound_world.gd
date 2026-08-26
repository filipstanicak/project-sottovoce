## **THE WORLD AS IT WAS, AROUND ONE POINT.** TDD-04 §8.2, US-0035.
##
## PURE — no Node, no autoload, no lookups.
##
## **MOVED FROM `scripts/net/server/` INTO CORE BY US-0060**, when it gained its
## first reader: `KillRules` is a pure rule and Core may not reference Net, so a
## value type living one layer up made the rule that consumes it illegal. It was
## always pure; it was filed beside the ring that produces it rather than beside
## the layer that may use it. What `LagCompHistory.rewind()` hands
## back, and at M4 the only thing a kill or stun validation is allowed to measure
## against.
##
## **IT CARRIES POSITIONS AND YAW AND NOTHING ELSE**, and the omissions are the
## design rather than an unfinished job. §8.2 rewinds transforms; it explicitly
## does **not** rewind suspicion tier, contract assignment or cooldowns, because
## each would hand an attacker something the present has already taken away — a
## tier the victim has left, a contract no longer theirs, a cooldown already
## spent. The way to keep that true under a year of M4 pressure is to have
## nowhere here to put them.
##
## Empty is a legitimate answer. A rewind to a tick the ring no longer holds, or
## to a corner of the district with nobody in it, returns an empty world rather
## than null — a caller that must branch on null will eventually forget to.
class_name RewoundWorld
extends RefCounted

## Entity ids, in no particular order. Peers and, from M3, NPC pool indices.
var ids := PackedInt32Array()
var positions := PackedVector3Array()
var yaws := PackedFloat32Array()

## The tick actually answered. **Not necessarily the tick asked for** — see
## `LagCompHistory.rewind()`, which clamps into the ring rather than failing.
var tick: int = -1


func size() -> int:
	return ids.size()


func is_empty() -> bool:
	return ids.is_empty()


func has(id: int) -> bool:
	return ids.has(id)


## Where `id` was, or `fallback` if it was not in this rewind.
##
## A caller that gets `fallback` has asked about an entity outside the radius or
## absent at that tick, and **must not** treat that as the origin: at M4 a kill
## validated against (0, 0, 0) would succeed from anywhere in the district for
## anyone standing near the map's corner.
func position_of(id: int, fallback := Vector3.INF) -> Vector3:
	var at := ids.find(id)
	return positions[at] if at >= 0 else fallback


func yaw_of(id: int, fallback := 0.0) -> float:
	var at := ids.find(id)
	return yaws[at] if at >= 0 else fallback


func add(id: int, position: Vector3, yaw: float) -> void:
	ids.append(id)
	positions.append(position)
	yaws.append(yaw)
