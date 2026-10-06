## **WHERE THE NET LIES, AND WHO A BLENDED PLAYER SEES GREYED.** US-0107. PURE.
##
## Both answers are drawn on one screen and decide nothing: the server has already
## said whether the player is blended (`blend_state`) and which civilians form a
## group (`NET-S2C-CROWD-GROUPS`). What is left is geometry over the figures this
## client draws, which is why it may live here and be measured without a server.
##
## **THE GREY NAMES THE GROUP, NOT THE RADIUS.** The reference greys the civilians
## the player is hiding with, so the player knows which ones the blend rests on —
## a walking group's members, the circle they stand in, the people on their bench.
## Greying everybody inside a radius would grey the passer-by too, and teach the
## player to trust somebody who is about to walk away.
class_name BlendCueRules
extends RefCounted

## How far beyond its outermost member a group's net reaches. Drawing only: the
## net is a picture of the group, and the reach a player may join from stays
## `TUN-BLEND-GROUP-JOIN-RADIUS`, asked on the server.
const NET_MARGIN := 0.8
## The radius of the net under one static prop.
const PROP_NET_RADIUS := 0.9
## Props closer than this belong to one piece of furniture. A bench's seats stand
## 0.8 m apart; the two lean spots of a stall stand its depth plus two agent radii,
## 2.8 m, apart — so one bench is one group and the two sides of a stall are two.
const PROP_LINK := 1.2
## A pocket net narrower than this is not drawn: a disc a player cannot stand in
## invites them somewhere they cannot be.
const MIN_POCKET_NET := 0.3


## The NPC indices to grey for a player blended as `kind` at `me`. `tags` is
## indexed by NPC, `drawn` maps an NPC index to where this client draws it, and
## `props` is the map's `static_props`. The player's own figure is the caller's.
static func greyed(
	kind: int, me: Vector3, tags: PackedByteArray, drawn: Dictionary, props: Array
) -> PackedInt32Array:
	match kind:
		BlendKind.Kind.GROUP:
			return _walking_group(me, tags, drawn)
		BlendKind.Kind.POCKET:
			return _standing_group(me, tags, drawn)
		BlendKind.Kind.PROP_STATIC:
			return _on_my_bench(me, tags, drawn, props)
	return PackedInt32Array()


## The members of the walking group nearest the player.
static func _walking_group(
	me: Vector3, tags: PackedByteArray, drawn: Dictionary
) -> PackedInt32Array:
	var mine := BlendGroupTag.NONE
	var best := INF
	for index: int in drawn:
		var tag := _tag(tags, index)
		var away := _flat(drawn[index], me)
		if BlendGroupTag.is_formation(tag) and away < best:
			best = away
			mine = tag
	return _tagged(tags, drawn, mine)


## The standing civilians the player's pocket rests on: every one within
## `TUN-BLEND-POCKET-RADIUS` the server says is standing — on its own feet or
## holding a seat — and no walker, though the server's count includes walkers. A
## walker is about to leave; greying them would teach the player to rely on them.
static func _standing_group(
	me: Vector3, tags: PackedByteArray, drawn: Dictionary
) -> PackedInt32Array:
	var out := PackedInt32Array()
	var reach := Tuning.suspicion.blend_pocket_radius
	for index: int in drawn:
		if BlendGroupTag.is_standing(_tag(tags, index)) and _flat(drawn[index], me) <= reach:
			out.append(index)
	return out


## **WHOEVER HOLDS ANOTHER SEAT OF THE PLAYER'S BENCH, BY THE RECORD, NOT BY
## DISTANCE** (review of #252). Distance greyed a passer-by brushing the player's
## counter and missed a sitter standing 0.7 m from a seat it holds — arrival is
## `TUN-CROWD-ANCHOR-ARRIVE-RADIUS`, 1.2 m. A stall counter holds one figure, so a
## player leaning there greys nobody but themselves.
static func _on_my_bench(
	me: Vector3, tags: PackedByteArray, drawn: Dictionary, props: Array
) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seats := furniture_of(nearest_prop(me, props), props)
	for index: int in drawn:
		if seats.has(BlendGroupTag.prop_of(_tag(tags, index))):
			out.append(index)
	return out


## The prop nearest `at`, or -1 for a map with none.
static func nearest_prop(at: Vector3, props: Array) -> int:
	var best := -1
	var best_distance := INF
	for i: int in props.size():
		var away := _flat(props[i], at)
		if away < best_distance:
			best_distance = away
			best = i
	return best


## Every prop linked to `start` by steps shorter than `PROP_LINK`: its bench.
static func furniture_of(start: int, props: Array) -> PackedInt32Array:
	var found := PackedInt32Array()
	if start < 0:
		return found
	found.append(start)
	var next := 0
	while next < found.size():
		for i: int in props.size():
			if not found.has(i) and _flat(props[i], props[found[next]]) < PROP_LINK:
				found.append(i)
		next += 1
	return found


## **ONE NET PER GROUP**, as `[centre, radius]`: each walking group, and the best
## guaranteed pocket in each knot of standing civilians.
##
## **A STANDING NET IS A PROMISE, AND IT IS KEPT EVERYWHERE IT IS DRAWN** (review of
## #252). The first version drew a net over every knot of standing civilians, and
## three of the four nets it drew round one granted pocket lay where the server
## refused one. Now a net is drawn only where the pocket rule holds at every point
## of it: see `_pocket_net`.
static func group_nets(tags: PackedByteArray, drawn: Dictionary) -> Array:
	var nets: Array = []
	var by_tag: Dictionary = {}
	var standing: Array = []
	for index: int in drawn:
		var tag := _tag(tags, index)
		if BlendGroupTag.is_formation(tag):
			if not by_tag.has(tag):
				by_tag[tag] = []
			(by_tag[tag] as Array).append(drawn[index])
		elif BlendGroupTag.is_standing(tag):
			standing.append(drawn[index])
	for tag: int in by_tag:
		nets.append(_net_over(by_tag[tag]))
	for knot: Array in _knots(standing, Tuning.suspicion.blend_pocket_radius * 0.5):
		var net := _pocket_net(knot, standing)
		if not net.is_empty():
			nets.append(net)
	return nets


## **THE LARGEST DISC ROUND THIS KNOT INSIDE WHICH A POCKET IS GUARANTEED**, or
## nothing. For a point `c`, let `d` be the distance to its
## `TUN-BLEND-POCKET-MIN-NPC`-th nearest standing civilian. Every point within
## `TUN-BLEND-POCKET-RADIUS - d` of `c` then has at least that many standing
## civilians within the pocket radius — the triangle inequality — and the server,
## which counts walkers too, can only find more. The knot's centroid and each of its
## members are tried as `c`; the best disc is drawn if it is wide enough to stand in.
static func _pocket_net(knot: Array, standing: Array) -> Array:
	var centre := Vector3.ZERO
	for p: Vector3 in knot:
		centre += p
	var candidates: Array = [centre / float(knot.size())] + knot
	var best: Array = []
	for c: Vector3 in candidates:
		var reach := Tuning.suspicion.blend_pocket_radius - _kth_nearest(c, standing)
		if reach >= MIN_POCKET_NET and (best.is_empty() or reach > float(best[1])):
			best = [c, reach]
	return best


## The distance from `at` to its `TUN-BLEND-POCKET-MIN-NPC`-th nearest point, or
## `INF` if there are not that many.
static func _kth_nearest(at: Vector3, points: Array) -> float:
	var k := int(Tuning.suspicion.blend_pocket_min_npc)
	if points.size() < k:
		return INF
	var away: Array = []
	for p: Vector3 in points:
		away.append(_flat(p, at))
	away.sort()
	return float(away[k - 1])


static func _knots(points: Array, link: float) -> Array:
	var knots: Array = []
	var left := points.duplicate()
	while not left.is_empty():
		var knot: Array = [left.pop_back()]
		var next := 0
		while next < knot.size():
			for i: int in range(left.size() - 1, -1, -1):
				if _flat(left[i], knot[next]) <= link:
					knot.append(left[i])
					left.remove_at(i)
			next += 1
		knots.append(knot)
	return knots


static func _net_over(points: Array) -> Array:
	var centre := Vector3.ZERO
	for p: Vector3 in points:
		centre += p
	centre /= float(points.size())
	var reach := 0.0
	for p: Vector3 in points:
		reach = maxf(reach, _flat(p, centre))
	return [centre, reach + NET_MARGIN]


static func _tagged(tags: PackedByteArray, drawn: Dictionary, tag: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if tag == BlendGroupTag.NONE:
		return out
	for index: int in drawn:
		if _tag(tags, index) == tag:
			out.append(index)
	return out


static func _tag(tags: PackedByteArray, index: int) -> int:
	return tags[index] if index >= 0 and index < tags.size() else BlendGroupTag.NONE


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
