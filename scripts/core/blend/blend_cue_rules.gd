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


## **ONE NET PER GROUP**, as `[centre, radius]`: each walking group, and each
## guaranteed pocket among the standing civilians.
##
## **A STANDING NET IS A PROMISE, AND IT IS KEPT EVERYWHERE IT IS DRAWN** (reviews
## of #252). The first version drew a net over every knot of standing civilians,
## and three of the four nets it drew round one granted pocket lay where the server
## refused one. Now a net is drawn only where the pocket rule holds at every point
## of it: see `_pocket_nets`.
static func group_nets(tags: PackedByteArray, drawn: Dictionary) -> Array:
	return walking_nets(tags, drawn) + standing_nets(tags, drawn)


## One net round each walking group's members. Cheap, and they move: every frame.
static func walking_nets(tags: PackedByteArray, drawn: Dictionary) -> Array:
	var by_tag: Dictionary = {}
	for index: int in drawn:
		var tag := _tag(tags, index)
		if BlendGroupTag.is_formation(tag):
			if not by_tag.has(tag):
				by_tag[tag] = []
			(by_tag[tag] as Array).append(drawn[index])
	var nets: Array = []
	for tag: int in by_tag:
		nets.append(_net_over(by_tag[tag]))
	return nets


## Every guaranteed pocket among the standing civilians. Standing civilians do not
## move, so `BlendCues` asks this only when the tags change or a few times a second.
static func standing_nets(tags: PackedByteArray, drawn: Dictionary) -> Array:
	var standing: Array = []
	for index: int in drawn:
		if BlendGroupTag.is_standing(_tag(tags, index)):
			standing.append(drawn[index])
	return _pocket_nets(standing)


## **EVERY DISC INSIDE WHICH A POCKET IS GUARANTEED**, widest first, none centred
## inside another. For a point `c`, let `d` be the distance to its
## `TUN-BLEND-POCKET-MIN-NPC`-th nearest standing civilian. Every point within
## `TUN-BLEND-POCKET-RADIUS - d` of `c` then has at least that many standing
## civilians within the pocket radius — the triangle inequality — and the server,
## which counts walkers too, can only find more.
##
## **THE CANDIDATES ARE EVERY STANDING CIVILIAN AND THE CENTRE OF ITS NEAREST FEW.**
## A circle's shared centre is the second for every one of its members. The third
## version first split the standing into knots at half a pocket radius, and a full
## circle whose members stood 2.8 m apart — within the arrival tolerance of real
## circle seats — fell into four singletons whose centre was never tried: no net
## over a 1.5 m guaranteed pocket (review of #252).
static func _pocket_nets(standing: Array) -> Array:
	var k := int(Tuning.suspicion.blend_pocket_min_npc)
	if standing.size() < k:
		return []
	var scored: Array = []
	for p: Vector3 in standing:
		for c: Vector3 in [p, _centre_of(_nearest(p, standing, k))]:
			var reach := Tuning.suspicion.blend_pocket_radius - _kth_nearest(c, standing)
			if reach >= MIN_POCKET_NET:
				scored.append([c, reach])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var nets: Array = []
	for net: Array in scored:
		if _clear_of(net, nets):
			nets.append(net)
	return nets


## True if `net`'s centre lies inside no drawn net, and no drawn net's inside it.
static func _clear_of(net: Array, nets: Array) -> bool:
	for other: Array in nets:
		if _flat(net[0], other[0]) < maxf(float(net[1]), float(other[1])):
			return false
	return true


## The `k` points nearest `at`, by insertion into a buffer of `k` — no full sort,
## because this runs for every standing civilian (measured 4 ms a call with sorts).
static func _nearest(at: Vector3, points: Array, k: int) -> Array:
	var near: Array = []
	var away: Array = []
	for p: Vector3 in points:
		var d := _flat(p, at)
		if near.size() == k and d >= float(away[k - 1]):
			continue
		var slot := near.size()
		while slot > 0 and float(away[slot - 1]) > d:
			slot -= 1
		near.insert(slot, p)
		away.insert(slot, d)
		if near.size() > k:
			near.pop_back()
			away.pop_back()
	return near


static func _centre_of(points: Array) -> Vector3:
	var centre := Vector3.ZERO
	for p: Vector3 in points:
		centre += p
	return centre / float(points.size())


## The distance from `at` to its `TUN-BLEND-POCKET-MIN-NPC`-th nearest point, or
## `INF` if there are not that many.
static func _kth_nearest(at: Vector3, points: Array) -> float:
	var k := int(Tuning.suspicion.blend_pocket_min_npc)
	if points.size() < k:
		return INF
	return _flat(_nearest(at, points, k)[k - 1], at)


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
