## **LAYER 4 OF FOUR, AND TDD-08 §5.1 CALLS IT THE ONE THAT ACTUALLY MATTERS.**
## TDD-08 §5, GDD-03 §6.3 rule 3, US-0047. SERVER ONLY.
##
## Layers 1 to 3 catch authoring mistakes, which review can see. This catches the
## **invisible** one: all twelve Lucerna drift north, the Lucerna player in the
## south market is now unique, every rule still works, the count is still 78, and
## they are simply, silently, findable.
##
## **IT RE-ROUTES AND NEVER RESPAWNS.** A clone appearing is a worse tell than the
## depletion it fixes, and re-personaing one breaks GDD-03 §6.3 rule 4 — a server
## describing a different city from the one its clients drew.
##
## **THE RE-ROUTE IS INVISIBLE BY CONSTRUCTION, NOT BY BEING RARE.** A strolling
## clone already walks to a random idle anchor; this only chooses *which*. The
## destination is city furniture, never the player, and it does not re-aim when the
## player moves — which is what "must not read as clones following players" means,
## and it is a property of the target rather than the rate.
##
## **HOLDING BEATS FETCHING, AND THE ARITHMETIC IS WHY.** A clone crosses the
## radius in about eighteen seconds and a hole opens the instant somebody walks out
## of one, so a fetch-only rule sat eighteen seconds under the minimum on every
## churn — measured, at zero. Each pass therefore first stops the clones already in
## a thin region from wandering out, at no travel cost. Fetching recovers from a
## hole; holding stops one opening.
##
## **THE STREAM IS BOUNDED BY ACCOUNTING, NOT BY A THROTTLE.** Nine passes per
## journey, so counting only *arrived* clones would send nine for a hole one deep —
## nine Lucerna converging on a market, the leak the story warns about. A clone on
## its way is counted against the fetch target, though **not** against the floor
## itself: see `_serve`.
class_name CloneBalance
extends RefCounted

## No clone was suitable. `-1` rather than 0, which is a real NPC index.
const NOBODY := -1

## index -> the anchor it is walking to on this system's orders. **Read by
## `CrowdIntent`, which peeks rather than consumes**: the reservation has to
## outlive the path query, or the clone stops counting as inbound the instant it
## sets off and the next pass sends another one.
var pending: Dictionary = {}

## What the last pass found and did. There is no other way to see from outside
## that this ran at all, and "it never re-routed anybody" satisfies every claim
## about re-routing being unobtrusive.
## (player, persona) pairs whose count was under the floor when the pass looked,
## **before** any inbound reservation is credited. `deficits_last_pass` is what
## survives that credit; the gap between them is what the accounting is doing.
var short_last_pass: int = 0

## Short pairs that had at least one clone already on its way to them.
var suppressed_last_pass: int = 0
var deficits_last_pass: int = 0
var rerouted_last_pass: int = 0
var held_last_pass: int = 0
var rerouted_total: int = 0
var held_total: int = 0

## This pass's **fetches only**, index -> anchor. Held insiders are re-routes too
## and go out in the same dictionary, but they are a different claim: a clone
## already standing in the region cannot have been taken from anybody, and the
## rule that nobody is robbed is only about the ones that travel.
var fetched: Dictionary = {}

## How many 2 s passes have run. **The only way to see the interval from
## outside**: a rule that ran every tick would produce the same re-routes and
## differ only in how often it looked, which is the story's first criterion.
var passes: int = 0

var _map: MapData = null
var _rng: RandomNumberGenerator = null

## index -> how far it was from its reservation at the previous pass. **The only
## thing that retires a reservation nobody can fulfil.** An NPC that cannot reach
## its anchor would otherwise hold a phantom inbound forever, and the symptom
## would be a local minimum quietly held at one instead of two.
var _closing: Dictionary = {}

## **WHICH RESERVATIONS ARE ACTUALLY A JOURNEY.** A hold and a fetch both land in
## `pending` and only a fetch is walking in from outside. A clone held for one
## player stands 24 m from them and 27 m from their neighbour, so to the neighbour
## it looks like an arrival that is never coming.
var _travelling: Dictionary = {}

# Pass scope: constant for the whole of one `rebalance()`, and held rather than
# threaded, because passing five unchanging arguments through four helpers makes
# every signature longer than the rule it serves.
var _pool: NpcPool = null
var _hash: SpatialHash = null
var _watchers: PackedVector3Array = PackedVector3Array()
var _radius: float = 25.0
var _least: int = 2

# Per watcher, recomputed once for each and read by all four personas. The region
# a player stands in does not depend on which persona is being served, and asking
# the grid four times for one answer is what made the 2 s pass the frame's spike.
var _nearby: Array[Vector3] = []
var _inside: PackedInt32Array = PackedInt32Array()
var _tally: Dictionary = {}


func setup(map: MapData, rng: RandomNumberGenerator) -> void:
	_map = map
	_rng = rng
	pending.clear()
	_closing.clear()
	_travelling.clear()


## One pass of the 2 s director timer. Returns index -> anchor for every clone
## the caller must now re-aim; empty on most passes.
##
## **NEVER PER TICK.** GDD-05 §5.2's reason for the slow interval is the one the
## formations have: the district must not visibly reorganise itself around a
## player who has just arrived.
func rebalance(
	hash: SpatialHash, pool: NpcPool, watchers: PackedVector3Array, personas: Array
) -> Dictionary:
	var sent: Dictionary = {}
	short_last_pass = 0
	suppressed_last_pass = 0
	deficits_last_pass = 0
	rerouted_last_pass = 0
	held_last_pass = 0
	fetched = {}
	passes += 1
	if pool == null or hash == null:
		return sent
	_pool = pool
	_hash = hash
	_watchers = watchers
	_radius = Tuning.crowd.clone_local_radius
	_least = int(Tuning.crowd.clone_local_min)
	_retire_the_finished_and_the_stuck()
	# **THE ANCHOR LIST IS PER PLAYER, NOT PER CLONE.** Which anchors sit inside a
	# region does not depend on the persona being served or on who is being sent
	# there, so scanning 62 anchors inside the innermost loop did that work
	# hundreds of times for one answer — measured as most of a 1.9 ms pass against
	# TDD-08 §11.2's 0.05 ms budget for the whole thing.
	for centre: Vector3 in watchers:
		_survey(centre)
		for persona: StringName in personas:
			_serve(centre, persona, sent)
	return sent


## Everything about one player's region that every persona then reads: the anchors
## inside it, who is standing in it, and how many of each identity that is.
##
## **ONE GRID QUERY PER PLAYER, NOT PER PERSONA.** A 25 m query walks about eighty
## cells of a 6 m grid; doing that four times for the same region, plus four
## `count_persona` walks over the same cells, was eight scans where one does.
func _survey(centre: Vector3) -> void:
	_nearby = _anchors_for(centre)
	_inside = _hash.query(centre, _radius)
	_tally = {}
	for index: int in _inside:
		var who := _pool.identity_of(index)
		_tally[who] = int(_tally.get(who, 0)) + 1


## The anchor chosen for `index`, or `NO_GOAL`. **A peek, deliberately** — see
## `pending`.
func take(index: int) -> Vector3:
	return pending.get(index, CrowdDirector.NO_GOAL)


## One player, one persona: hold what is there, then fetch what is missing.
##
## **THE FLOOR IS DECIDED ON CLONES THAT HAVE ARRIVED.** Crediting one still
## walking satisfies the minimum in expectation while the player is short in fact
## for the whole eighteen-second journey — measured, the pass saw 41 short pairs
## and acted on 3. `_inbound` still bounds the stream; it no longer decides whether
## there is a problem. **And the fetch targets one above the floor**, so an arrival
## lands before the next departure takes the region back under.
func _serve(centre: Vector3, persona: StringName, sent: Dictionary) -> void:
	var near: int = _tally.get(persona, 0)
	if near < _least:
		short_last_pass += 1
	if near <= _least:
		_hold_the_insiders(persona, sent)
	if near >= _least:
		return
	var coming := _inbound(persona, centre)
	if coming > 0:
		suppressed_last_pass += 1
	if near + coming <= _least:
		_fetch_one(persona, sent)


## Send the nearest spare clone of `persona` to an anchor in this region.
func _fetch_one(persona: StringName, sent: Dictionary) -> void:
	deficits_last_pass += 1
	var target := _pick(_nearby)
	if target == CrowdDirector.NO_GOAL:
		return
	var who := _nearest_spare(persona, target)
	if who == NOBODY:
		return
	_reserve(who, target, sent)
	_travelling[who] = true
	fetched[who] = target
	rerouted_last_pass += 1
	rerouted_total += 1


## **THE HALF THAT ACTUALLY HOLDS THE FLOOR.** A clone of a thin persona that is
## inside the region is about to become the hole: an anchor on this side of the
## region keeps it, at no travel cost, and nothing observable changes because it
## walks to a bench either way.
##
## **IDLE CLONES ARE RESERVED AND NOT WOKEN, AND THAT IS THE WHOLE DIFFERENCE
## BETWEEN 0.7 % AND NONE.** Holding only walkers leaves a two-second window every
## pass: an idle clone near the edge starts strolling, picks a far anchor and is
## outside before anybody looks again — measured, 91 readings of 12 960 under the
## floor. A reservation costs it nothing now and is simply what `CrowdIntent`
## hands it when its pause ends on its own. Cutting the pause short instead would
## be motion the region did not need, and motion is the thing that reads.
## **ASKS THE GRID RATHER THAN THE WHOLE CROWD.** `SpatialHash.query()` answers
## "who is inside this region" from a cell range; scanning all ninety and throwing
## away the ones outside is the O(pawns x NPCs) cost US-0042 exists to remove,
## and doing it once per player *per persona* did it twenty-four times a pass.
func _hold_the_insiders(persona: StringName, sent: Dictionary) -> void:
	if _nearby.is_empty():
		return
	for index: int in _inside:
		if _pool.identity_of(index) != persona or pending.has(index):
			continue
		var brain := _pool.brain_of(index)
		if brain == null or not _is_spare(brain):
			continue
		var target := _pick(_nearby)
		pending[index] = target
		if brain.state == NpcBrain.State.STROLL:
			sent[index] = target
		held_last_pass += 1
		held_total += 1


## Is this NPC's next destination the director's to choose? A startled, gawking
## or processing NPC is doing something the design gave it, and layer 4 does not
## outrank a startle wave or a corpse.
static func _is_spare(brain: NpcBrain) -> bool:
	return brain.state == NpcBrain.State.STROLL or brain.state == NpcBrain.State.IDLE


func _reserve(index: int, target: Vector3, sent: Dictionary) -> void:
	pending[index] = target
	sent[index] = target


## Forget every reservation that has done its job or never will.
##
## A clone that has arrived is counted by the hash from now on, so the hand-off
## from *inbound* to *here* is exactly this erase. A clone that got startled,
## recruited or sent to a corpse has stopped walking where it was sent. And a
## clone no closer than it was a whole pass ago is not going to get there.
func _retire_the_finished_and_the_stuck() -> void:
	var arrive: float = Tuning.crowd.anchor_arrive_radius
	arrive *= arrive
	for index: int in pending.keys():
		var brain := _pool.brain_of(index)
		var body := _pool.body_of(index)
		if brain == null or body == null or not _pool.is_active(index) or not _is_spare(brain):
			_forget(index)
			continue
		var gap := _flat_squared(body.global_position, pending[index])
		if gap <= arrive:
			_forget(index)
			continue
		# **THE PROGRESS TEST APPLIES TO WALKERS ONLY.** An idle clone is standing
		# still on purpose, and measuring it against its own last distance would
		# retire every reservation made for one exactly one pass after it was made.
		if brain.state != NpcBrain.State.STROLL:
			continue
		if gap >= float(_closing.get(index, INF)):
			_forget(index)
			continue
		_closing[index] = gap


func _forget(index: int) -> void:
	pending.erase(index)
	_closing.erase(index)
	_travelling.erase(index)


## Clones of `persona` **walking into** this region that are not standing in it
## yet. Counting the ones already inside would double-count them against the hash,
## and counting the ones merely *held* elsewhere would credit the region an
## arrival that is never coming — see `_travelling`.
func _inbound(persona: StringName, centre: Vector3) -> int:
	var coming := 0
	var reach := _radius * _radius
	for index: int in pending:
		if not _travelling.has(index) or _pool.identity_of(index) != persona:
			continue
		if _flat_squared(pending[index], centre) > reach:
			continue
		var body := _pool.body_of(index)
		if body != null and _flat_squared(body.global_position, centre) > reach:
			coming += 1
	return coming


## A place inside the under-served region for somebody to walk to.
##
## **AN ANCHOR, NEVER THE PLAYER'S POSITION.** GDD-05 puts anchors where a city
## would actually gather; a clone sent to one arrives and stands there like every
## other civilian, which is what makes the re-route unreadable. Sent at a player
## instead, the crowd would visibly converge on whoever was alone.
##
## **AND NOT AN ANCHOR ON THE BOUNDARY.** A clone parked at 24.8 m is inside this
## player's radius and outside their neighbour's, and it leaves the region again
## the moment either of them takes a step. The margin is one pass of walking —
## `TUN-CROWD-NPC-SPEED-STROLL` × `TUN-CROWD-DIRECTOR-INTERVAL`, about 2.8 m —
## because one pass is exactly how long nobody is looking. Derived, so retuning
## either number moves it. The full radius is used when nothing is nearer, since
## an anchor on the edge still beats no anchor at all.
func _anchors_for(centre: Vector3) -> Array[Vector3]:
	if _map == null or _map.idle_anchors.is_empty():
		return []
	var margin: float = Tuning.crowd.npc_speed_stroll * Tuning.crowd.director_interval
	var inside := _anchors_within(centre, maxf(_radius - margin, _radius * 0.5))
	return inside if not inside.is_empty() else _anchors_within(centre, _radius)


## One of them, from the seeded generator. Never `randf` — rule 8.
func _pick(anchors: Array[Vector3]) -> Vector3:
	if anchors.is_empty():
		return CrowdDirector.NO_GOAL
	if _rng == null:
		return anchors[0]
	return anchors[_rng.randi_range(0, anchors.size() - 1)]


func _anchors_within(centre: Vector3, reach: float) -> Array[Vector3]:
	var found: Array[Vector3] = []
	var limit := reach * reach
	for anchor: Vector3 in _map.idle_anchors:
		if _flat_squared(anchor, centre) <= limit:
			found.append(anchor)
	return found


## The clone that should be fetched, or `NOBODY`.
##
## **NOBODY IS ROBBED TO PAY SOMEBODY ELSE.** A candidate standing inside *any*
## watcher's region is already somebody's local minimum, and moving it would trade
## one player's anonymity for another's — with the two oscillating and neither
## ever holding two.
##
## **STROLLERS FIRST, AND THAT IS NOT A TIE-BREAK.** Re-routing a walker changes
## only its destination. Taking an idle one empties a seat at an anchor, and
## `TUN-BLEND-POCKET-MIN-NPC` needs four NPCs standing together for the *other*
## blend to exist at all — so the cheap-looking choice quietly costs hiding places.
func _nearest_spare(persona: StringName, target: Vector3) -> int:
	var walker := NOBODY
	var walker_gap := INF
	var stander := NOBODY
	var stander_gap := INF
	for index: int in _pool.active_count():
		if _pool.identity_of(index) != persona or pending.has(index):
			continue
		var brain := _pool.brain_of(index)
		var body := _pool.body_of(index)
		if brain == null or body == null or not _is_spare(brain):
			continue
		if _is_somebodys_minimum(body.global_position):
			continue
		var gap := _flat_squared(body.global_position, target)
		if brain.state == NpcBrain.State.STROLL and gap < walker_gap:
			walker = index
			walker_gap = gap
		elif brain.state == NpcBrain.State.IDLE and gap < stander_gap:
			stander = index
			stander_gap = gap
	return walker if walker != NOBODY else stander


func _is_somebodys_minimum(point: Vector3) -> bool:
	var reach := _radius * _radius
	for centre: Vector3 in _watchers:
		if _flat_squared(point, centre) <= reach:
			return true
	return false


## Horizontal, like every other radius in this design: a clone on a 3.5 m balcony
## is not further from the player below in any sense anonymity cares about.
##
## **SQUARED, BECAUSE NOTHING HERE WANTS A DISTANCE.** Every caller compares — to a
## radius, to an arrival tolerance, or to another candidate — and an ordering is
## the same under the square. `SpatialHash` made the same choice for the same
## reason, and this file runs its comparisons thousands of times a pass.
static func _flat_squared(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz
