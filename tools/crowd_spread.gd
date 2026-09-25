extends RefCounted
## **THE ARITHMETIC OF `crowd_spread_census`, PURE, SO IT CAN BE CHECKED.** US-0103.
## DEBUG TOOL.
##
## Samples in, counts out: no scene, no clock. The census scene feeds it frames of
## `{index: [position, state]}`; the tests feed it frames whose answer is known.
##
## **SPLIT OUT BECAUSE THE REVIEW OF #237 FOUND TWO WAYS THE FIRST VERSION MIXED THE
## TWO CAUSES IT EXISTS TO SEPARATE**, and the tool had no test that could have said so:
##
## - a walk whose two samples straddled a **state change** was booked to the new
##   state, so a stroller stopping read as an IDLE figure walking, and a procession
##   member peeling off read as stroller movement;
## - a stroller walking beside a **procession** counted as company, so the stroller
##   figure measured rows *or* processions, not strollers forming rows.
##
## Both are fixed here, and each has a synthetic test that reddens without the fix.

## Another walker this close and heading this similarly is company.
const COMPANY_RADIUS := 3.0
const COMPANY_HEADING := 0.6
## Faster than this between two samples is walking.
const WALKING := 0.5
## A cell this many different strollers crossed is a shared lane.
const SHARED_LANE := 5


## `{index: [position, heading, state]}` for everybody walking between two samples.
## **An interval whose two samples disagree about the state is dropped**: the
## movement belongs to neither state, and booking it to either is the defect above.
static func walkers(before: Dictionary, now: Dictionary, dt: float) -> Dictionary:
	var out := {}
	for index: int in now:
		if not before.has(index) or before[index][1] != now[index][1]:
			continue
		var a: Vector3 = before[index][0]
		var b: Vector3 = now[index][0]
		if CompassMath.distance_to(a, b) / dt < WALKING:
			continue
		out[index] = [b, CompassMath.bearing_to(a, b), now[index][1]]
	return out


## Whether `index` walks beside another walker heading the same way. With
## `same_state` only walkers in its own state count, which is what says whether
## strollers form rows **among themselves**.
static func has_company(index: int, moving: Dictionary, same_state: bool) -> bool:
	var me: Array = moving[index]
	for other: int in moving:
		if other == index:
			continue
		var them: Array = moving[other]
		if same_state and them[2] != me[2]:
			continue
		if CompassMath.distance_to(me[0], them[0]) > COMPANY_RADIUS:
			continue
		if absf(CompassMath.angle_between(me[1], them[1])) < COMPANY_HEADING:
			return true
	return false


## Counted once over the whole watch: samples per state, walkers per state, walkers
## with same-state and with any company, and for `stroll` the cells crossed and by
## whom.
static func tally(samples: Array, dt: float, stroll: int) -> Dictionary:
	var t := {"share": {}, "walking": {}, "same": {}, "any": {}, "lanes": {}, "cells": []}
	for i: int in range(1, samples.size()):
		for index: int in samples[i]:
			_bump(t["share"], samples[i][index][1])
		var moving := walkers(samples[i - 1], samples[i], dt)
		for index: int in moving:
			var state: int = moving[index][2]
			_bump(t["walking"], state)
			if has_company(index, moving, true):
				_bump(t["same"], state)
			if has_company(index, moving, false):
				_bump(t["any"], state)
			if state == stroll:
				var cell := Vector2i(floori(moving[index][0].x), floori(moving[index][0].z))
				var seen: Dictionary = t["lanes"].get(cell, {})
				seen[index] = true
				t["lanes"][cell] = seen
				(t["cells"] as Array).append(cell)
	return t


## The share of stroller walking samples that lie on a shared lane.
static func shared_lane_share(t: Dictionary) -> float:
	var cells: Array = t["cells"]
	if cells.is_empty():
		return 0.0
	var lanes: Dictionary = t["lanes"]
	var shared := cells.filter(
		func(c: Vector2i) -> bool: return (lanes[c] as Dictionary).size() >= SHARED_LANE
	)
	return float(shared.size()) / cells.size()


static func _bump(counts: Dictionary, key: int) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
