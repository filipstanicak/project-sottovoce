## **WHERE A STROLL ENDS: ALONE, IN A CIRCLE, OR AT A COUNTER.** US-0103, GDD-03 §6.3
## rule 7. SERVER ONLY.
##
## Measured before this existed: **0 %** of idle NPCs had an idle neighbour, and no NPC
## ever leaned at a stall counter. So a player standing with others, or leaning at a
## counter, was doing what no civilian in the district ever did — the clone rule broken
## by an absence. The reference's civilians stand in circles and use the blend props
## players use (sources in the chat log of 2026-09-25, never here, never-do #5).
##
## **A CIRCLE IS AN ANCHOR WITH MEMBERS.** Its size is drawn between
## `TUN-CROWD-IDLE-GROUP-SIZE-MIN` and `-MAX` when its first member is sent to it, the
## members stand `TUN-CROWD-CIRCLE-RADIUS` from the anchor evenly round it, and a full
## circle is a blend pocket (invariant 38). Members leave on their own idle timers, so
## a circle thins out the way a conversation does.
##
## **A COUNTER IS A `LeanSpots` SPOT**, the one record `SYS-BLEND` takes spots from for
## players, so an NPC never leans where a player leans and the reverse.
class_name CrowdPlaces
extends RefCounted

var _map: MapData = null
var _rng: RandomNumberGenerator = null
var _spots: LeanSpots = null
## anchor index -> its seats, one per member it is sized for: an NPC index, or -1.
var _circles: Dictionary = {}
## NPC index -> anchor index of the circle it belongs to.
var _circle_of: Dictionary = {}
## NPC index -> the counter it set off for. Kept apart from `LeanSpots`' reservation,
## which a player cancels, so an arrival can tell *walked to a counter and lost it*
## from *walked to an anchor*.
var _to_counter: Dictionary = {}


func setup(map: MapData, rng: RandomNumberGenerator, spots: LeanSpots) -> void:
	_map = map
	_rng = rng
	_spots = spots
	_circles.clear()
	_circle_of.clear()
	_to_counter.clear()


## Where NPC `index`, standing at `here`, should end its stroll, or
## `CrowdDirector.NO_GOAL` for an anchor of the caller's choosing. Draws from the
## seeded generator only.
func goal_for(index: int, here: Vector3) -> Vector3:
	release(index)
	if _map == null or _rng == null:
		return CrowdDirector.NO_GOAL
	var roll := _rng.randf()
	if roll < Tuning.crowd.lean_chance:
		# A full market sends the stroller to an anchor, never into a circle the draw
		# did not choose.
		return _a_counter(index)
	if roll < Tuning.crowd.lean_chance + Tuning.crowd.circle_chance:
		return _join_a_circle(index, here)
	return CrowdDirector.NO_GOAL


func _a_counter(index: int) -> Vector3:
	if _spots == null:
		return CrowdDirector.NO_GOAL
	var spot := _spots.a_vacant_spot(_rng, _map.static_props.size())
	if spot == LeanSpots.VACANT or not _spots.reserve_for_npc(index, spot):
		return CrowdDirector.NO_GOAL
	_to_counter[index] = spot
	return _map.static_props[spot]


## NPC `index` arrived where it was going. A reserved counter becomes its own; **false
## if a player took it on the way** — the caller must send the NPC on, or two figures
## stand at one counter (review of #250).
func arrived(index: int) -> bool:
	if not _to_counter.has(index):
		return true
	_to_counter.erase(index)
	return _spots != null and _spots.arrive(index)


## NPC `index` left wherever it was: its counter and its circle are free again.
func release(index: int) -> void:
	_to_counter.erase(index)
	if _spots != null:
		_spots.release_npc(index)
	if not _circle_of.has(index):
		return
	var anchor: int = _circle_of[index]
	_circle_of.erase(index)
	var seats: Array = _circles[anchor]
	seats[seats.find(index)] = -1
	if seats.count(-1) == seats.size():
		_circles.erase(anchor)


## How many circles stand, and how many figures are in them. For the census.
func circles() -> int:
	return _circles.size()


func in_circles() -> int:
	return _circle_of.size()


## **A CIRCLE IS JOINED NEARBY OR STARTED NEARBY, NEVER ACROSS THE DISTRICT.** The
## first version sent members to random anchors, and measured nothing: a stroll across
## the district takes longer than the 8–25 s the first member stands, so a circle's
## members never stood there at the same time. A circle with a free seat within
## `TUN-CROWD-CIRCLE-JOIN-RADIUS` is joined; otherwise one is started at the nearest
## anchor, where the next strollers passing will find it. An anchor already holding a
## full circle sends the NPC on alone. A member's place is its seat, evenly round the
## anchor, kept while it stays.
func _join_a_circle(index: int, here: Vector3) -> Vector3:
	if _map.idle_anchors.is_empty():
		return CrowdDirector.NO_GOAL
	var anchor := _an_open_circle(here)
	if anchor < 0:
		anchor = _nearest_anchor(here)
		if _circles.has(anchor):
			return CrowdDirector.NO_GOAL
		var c := Tuning.crowd
		var seats: Array = []
		seats.resize(_rng.randi_range(c.idle_group_size_min, c.idle_group_size_max))
		seats.fill(-1)
		_circles[anchor] = seats
	var seats: Array = _circles[anchor]
	var seat := seats.find(-1)
	seats[seat] = index
	_circle_of[index] = anchor
	var turn := TAU * float(seat) / float(seats.size())
	return (
		_map.idle_anchors[anchor] + Vector3(cos(turn), 0.0, sin(turn)) * Tuning.crowd.circle_radius
	)


func _an_open_circle(here: Vector3) -> int:
	var reach := Tuning.crowd.circle_join_radius
	for anchor: int in _circles:
		if (_circles[anchor] as Array).has(-1):
			if CompassMath.distance_to(here, _map.idle_anchors[anchor]) <= reach:
				return anchor
	return -1


func _nearest_anchor(here: Vector3) -> int:
	var best := 0
	for anchor: int in _map.idle_anchors.size():
		var d := CompassMath.distance_to(here, _map.idle_anchors[anchor])
		if d < CompassMath.distance_to(here, _map.idle_anchors[best]):
			best = anchor
	return best
