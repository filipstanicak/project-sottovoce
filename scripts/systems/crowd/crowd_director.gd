## **`SYS-CROWD`. THE THING THAT TICKS NINETY BRAINS.** TDD-08 §8, US-0041.
## SERVER ONLY.
##
## Registered at the `crowd` stage, which runs **before** suspicion for a reason
## `SystemOrder` states: `TUN-SUSPICION-GAIN-OPEN` asks whether an NPC is within
## `TUN-SUSPICION-OPEN-RADIUS`, and a tick of lag lets a player be "alone" inside
## a pocket that has already re-formed.
##
## **THIS FILE OWNS THE STATE KNOWLEDGE AND `Steering` OWNS NONE.** The whole
## division is `_goal_for()` and `_speed_for()`: a state becomes a point and a
## number here, and everything downstream sees only the point and the number.
## That is US-0041's fourth acceptance criterion, and `test_steering_knows_no_states.gd`
## enforces the half of it that can be enforced by reading.
##
## **WHAT IS NOT HERE YET, SAID PLAINLY.** Only Stroll and Idle can actually be
## reached today: nothing assigns a formation slot (US-0043), nothing grants a
## gawk token (US-0044) and nothing sets `startle_flag` (US-0044 again). Startle's
## goal and speed are implemented anyway and tested by setting the flag by hand,
## because the steering layer is what US-0044 will hang off — but a crowd that
## only strolls and stands is what a server actually runs this milestone.
##
## **LOD BANDS THE BRAIN AND NOTHING ELSE**, US-0045. Steering, the formations and
## the hash run every tick for every active NPC; only `NpcBrain.step()` is rated,
## because that is what TDD-08 §4.1 specifies and what ADR-0003 permits. US-0048
## measured what that is worth before it was built: the brains are 0.046 ms of a
## 5.7 ms crowd, so the saving is under 1 % — see §11.2.1 for where the cost
## actually is.
class_name CrowdDirector
extends GameSystem

## No goal. `Vector3.INF` rather than `Vector3.ZERO`, because the origin is a
## real place on this map — the same reason `RewoundWorld.position_of` uses it.
const NO_GOAL := Vector3.INF

## How many path queries the last tick actually issued. Read by the tests that
## assert the stagger; there is no other way to observe a cap from outside.
var served_last_tick: int = 0

## **WHICH PERSONAS THE LOCAL MINIMUM IS HELD FOR**, GDD-03 §6.3 rule 3. Nothing
## chooses a persona for a player yet — no lobby, `NET-C2S-LOADOUT` is M4's — so
## every pawn's is `&""`, and all four are treated as in use exactly as
## `server_root` already does for `NpcPool.activate`. `SYS-MATCH` narrows it to
## the real loadouts at M4, which makes the rule cheaper and never weaker.
var personas_in_use: Array[StringName] = CrowdRoster.PLAYABLE.duplicate()

var _pool: NpcPool = null
var _map: MapData = null
var _rng: RandomNumberGenerator = null
var _steering := Steering.new()
var _repath := RepathQueue.new()
var _formations := CrowdFormations.new()
var _intent := CrowdIntent.new()
var _alarm := CrowdAlarm.new()
var _clones := CloneBalance.new()
var _bands := CrowdBands.new()

## The shared grid, held from `setup()` so the public startle and corpse entry
## points can be called from outside a tick — `SYS-KILL` resolves a kill in the
## `combat` stage, which is four positions after `crowd` in `SystemOrder`.
var _hash: SpatialHash = null

## This tick's number, so `_advance` can ask whether an NPC is due without being
## handed the whole context.
var _tick: int = 0
var _corpses := CorpseRegister.new()

## Net ticks between sprinter sweeps, from `TUN-CROWD-STARTLE-SPRINT-INTERVAL`.
## GDD-03 §6.4 evaluates the sprint startle **once per second, not per tick**: at
## 30 Hz, a player running past a market would otherwise fire thirty overlapping
## waves a second and the crowd would scatter as a solid radius rather than as a
## trail.
var _sweep_ticks: int = 30

## Net ticks between rebalances, from `TUN-CROWD-DIRECTOR-INTERVAL`. **Derived
## from the tick, never accumulated** — the same rule `MatchDirector` follows, and
## for the same reason: an accumulator drifts and fires twice after a hitch.
var _rebalance_ticks: int = 60

## Live positions, refilled each tick and handed to the spatial hash. A member
## rather than a local, because the hash copies out of it and a fresh
## `PackedVector3Array` every tick is ninety NPCs' worth of garbage a second.
var _here: PackedVector3Array = PackedVector3Array()

## How many brains actually stepped last tick. §4.1 predicts ~34 of 90; there is
## no other way to see the reduction from outside.
var _stepped_last_tick: int = 0

## Where each NPC is walking, parallel to the pool. `NO_GOAL` means "needs one",
## which is what puts it in the repath queue.
var _goals: PackedVector3Array = PackedVector3Array()


func stage() -> StringName:
	return &"crowd"


## **A CROWD IS OPTIONAL AND ITS ABSENCE IS NOT AN ERROR.** The integration
## harness stands up a server with no NPCs at all, and so does every client.
func setup(ctx: MatchContext) -> void:
	_pool = ctx.crowd
	_map = ctx.map
	_rng = ctx.rng
	_hash = ctx.crowd_hash
	if _pool == null:
		return
	if not Tuning.reloaded.is_connected(_steering.refresh):
		Tuning.reloaded.connect(_steering.refresh)
	if not Tuning.reloaded.is_connected(_intent.refresh):
		Tuning.reloaded.connect(_intent.refresh)
	_rebalance_ticks = maxi(Tuning.ticks(&"TUN-CROWD-DIRECTOR-INTERVAL"), 1)
	_sweep_ticks = maxi(Tuning.ticks(&"TUN-CROWD-STARTLE-SPRINT-INTERVAL"), 1)
	_formations.setup(ctx.map)
	_clones.setup(ctx.map, _rng)
	_intent.setup(_pool, ctx.map, _rng, _formations, _corpses, _clones)
	_goals.resize(_pool.body_count())
	_here.resize(_pool.body_count())
	ctx.crowd_hash.setup(ctx.map.bounds if ctx.map != null else AABB(), _pool.body_count())
	for index: int in _pool.body_count():
		_goals[index] = NO_GOAL
		var body := _pool.body_of(index)
		var agent := _pool.agent_of(index)
		if body == null or agent == null:
			continue
		_steering.configure(body, agent, _pool.is_active(index))
		_steering.attach(body, agent)
		_pool.context_of(index).rng = _rng
	# Last: it seeds every agent's path tolerance, and `Steering` only knows the
	# engine's default once it has configured one.
	_bands.setup(_pool, _steering)


## One tick: every active brain, then the staggered path queries.
##
## **THE QUERIES ARE SERVED LAST, ON PURPOSE.** Requests made this tick are
## eligible this tick, so an NPC that just arrived somewhere is not made to wait
## a whole tick standing still before it is even considered.
func tick(ctx: MatchContext, dt: float) -> void:
	if _pool == null:
		return
	_tick = ctx.tick
	_reindex(ctx)
	_bands.evaluate(ctx.pawns)
	# **THE 2 S TIMER RUNS BEFORE THE BRAINS**, so a slot assigned this tick is a
	# `slot_assigned` flag the brain consumes this tick rather than next. GDD-05
	# §5.2 makes the interval slow on purpose: visible re-forming is itself an
	# information leak.
	if ctx.tick % _rebalance_ticks == 0:
		_formations.rebalance(ctx.crowd_hash, _pool)
		_corpses.forget_departed(_pool)
		_rebalance_clones(ctx)
	# **BODIES AGE ON THE TICK, NOT ON THE 2 S PASS.** `TUN-CORPSE-LIFETIME` is 20 s
	# and the two information phases it produces are 6 s and 14 s long; checking
	# every two seconds would blur a boundary players are meant to read.
	_corpses.expire(ctx.tick, _pool)
	if ctx.tick % _sweep_ticks == 0:
		_alarm.sweep_for_sprinters(ctx, ctx.crowd_hash, _pool)
	_stepped_last_tick = 0
	for index: int in _pool.active_count():
		_advance(index, dt)
	_serve_repaths()
	# Last, because a formation slot is where an NPC must be *after* its brain has
	# decided it is still in the group.
	_formations.advance(_pool, _steering, dt)


## **THE HASH IS BUILT BEFORE THE BRAINS, NOT AFTER.** TDD-08 §1's diagram feeds
## it into them: startle propagation asks who is nearby (US-0044), and a hash
## rebuilt afterwards would answer every brain with the previous tick's crowd
## while every *system* downstream got this tick's. One of the two would be wrong
## and neither would say so.
func _reindex(ctx: MatchContext) -> void:
	var active := _pool.active_count()
	for index: int in active:
		var body := _pool.body_of(index)
		if body != null:
			_here[index] = body.global_position
	ctx.crowd_hash.rebuild(_here, _pool.roster, active)


## How many brains stepped on the last tick, and how many were active. §4.1's
## table predicts about 34 of 90.
func lod_load() -> Vector2i:
	return Vector2i(_stepped_last_tick, _pool.active_count() if _pool != null else 0)


## **LAYER 4 OF FOUR**, TDD-08 §5.1. `CloneBalance` holds the whole decision;
## this applies it, and applying it is three lines.
##
## **THE GOAL IS CLEARED, NOT OVERWRITTEN.** `_advance` asks for a path only when
## the goal is `NO_GOAL`, so writing the anchor in directly would leave the agent
## aimed where it already was and the re-route unserved until the clone arrived
## somewhere else — a minute away. Cleared, the ordinary repath runs and
## `CrowdIntent` answers it with the reservation.
func _rebalance_clones(ctx: MatchContext) -> void:
	var sent := _clones.rebalance(ctx.crowd_hash, _pool, _bands.watchers, personas_in_use)
	for index: int in sent:
		var brain := _pool.brain_of(index)
		if brain == null:
			continue
		_goals[index] = NO_GOAL
		# **ONLY A FETCHED IDLE CLONE IS WOKEN.** A held one keeps its reservation
		# and its pause; a fetched one has somewhere to be.
		if brain.state == NpcBrain.State.IDLE:
			brain.handle(NpcBrain.Event.TIMER_EXPIRED, _pool.context_of(index))


## The band `index` is in right now. Read by `test_crowd_lod.gd`.
func band_of(index: int) -> int:
	return _bands.band_of(index)


func teardown() -> void:
	_repath.clear()
	_corpses.clear()
	_goals.resize(0)


## One NPC: deliver what happened to it, step it, then ask for what it now needs.
##
## **LOD RATES THE BRAIN AND ONLY THE BRAIN.** Goals, the repath request and
## steering run every tick for every NPC — a body driven at a third of the rate
## would move at a third of the speed, and `TUN-CROWD-NPC-SPEED-STROLL` is the one
## number the crowd cannot get wrong.
func _advance(index: int, dt: float) -> void:
	var brain := _pool.brain_of(index)
	var cctx := _pool.context_of(index)
	var agent := _pool.agent_of(index)
	if brain == null or cctx == null or agent == null:
		return

	# **ARRIVAL IS ONLY MEANINGFUL WHEN THERE IS SOMEWHERE TO ARRIVE.** An agent
	# with no target reports `is_navigation_finished()` as true, so testing it
	# unconditionally would fire REACHED_ANCHOR on the first tick of every match
	# and walk the whole crowd into Idle before anybody had gone anywhere.
	if _goals[index] != NO_GOAL and _steering.arrived(agent):
		cctx.reached_anchor = true
		_goals[index] = NO_GOAL

	var before: int = brain.state
	_think(index, brain, cctx, dt)

	# A state change invalidates wherever it was going: a startled NPC must stop
	# walking to the bench it had picked.
	if brain.state != before:
		_goals[index] = NO_GOAL
	if _goals[index] == NO_GOAL and _intent.travels(brain.state):
		_repath.request(index)

	# **A GROUP MEMBER IS STEERED BY ITS FORMATION, NOT BY A PATH.** Returning here
	# is what keeps the two out of each other's way: driven from both, an NPC would
	# get two desired velocities a tick and take whichever was set last.
	if brain.state == NpcBrain.State.WALKING_GROUP:
		return
	_steering.drive(_pool.body_of(index), agent, _intent.speed_for(brain.state))


## **EVENTS ARE CLEARED ONLY WHEN SOMEBODY READ THEM.** Clearing every tick
## regardless is the exact failure ADR-0003 forbids: a `startle_flag` raised on a
## tick a Far NPC was not due to think would be wiped unseen, so **LOD would
## silently drop startles and gawk tokens** for two thirds of the crowd. Trap 11
## note: this docstring is charged to `_advance` above, so it stays short.
func _think(index: int, brain: NpcBrain, cctx: CrowdContext, dt: float) -> void:
	var band := _bands.band_of(index) as CrowdLod.Band
	if not CrowdLod.due(band, _tick, index):
		return
	_stepped_last_tick += 1
	brain.step(cctx, dt, CrowdLod.stride_of(band))
	_dispatch(brain, cctx)
	cctx.clear_events()


## **THE FLAGS `NpcBrain.step()` DOES NOT READ.** Its hot path is three
## operations and handles only the interrupt and the timer; every other event is
## a `CrowdContext` flag that somebody has to turn into a `handle()` call, and
## this is that somebody. Doing it inside `step()` would put five branches on a
## path that runs ninety times a tick to serve events that fire rarely.
func _dispatch(brain: NpcBrain, cctx: CrowdContext) -> void:
	if cctx.reached_anchor:
		brain.handle(NpcBrain.Event.REACHED_ANCHOR, cctx)
	if cctx.slot_assigned:
		brain.handle(NpcBrain.Event.SLOT_ASSIGNED, cctx)
	if cctx.slot_revoked:
		brain.handle(NpcBrain.Event.SLOT_REVOKED, cctx)
	if cctx.gawk_granted:
		brain.handle(NpcBrain.Event.GAWK_GRANTED, cctx)
	if cctx.corpse_gone:
		brain.handle(NpcBrain.Event.CORPSE_GONE, cctx)


## Hand out this tick's ration of path queries.
func _serve_repaths() -> void:
	var served := _repath.take(Tuning.perf.crowd_repath_per_tick)
	served_last_tick = served.size()
	for index: int in served:
		var brain := _pool.brain_of(index)
		var goal := _intent.goal_for(index, brain.state)
		_goals[index] = goal
		if goal != NO_GOAL:
			_steering.aim(_pool.agent_of(index), goal)


## Does this state move? Idle stands still by definition; the other two that do
## not travel are waiting for the systems that would tell them where to go.
## **THE PLAYER-FACING HALF OF A FORMATION SLOT.** `SYS-BLEND` (US-0053) is what
## will call these when `INPUT-BLEND` arrives within `TUN-BLEND-GROUP-JOIN-RADIUS`
## of a group; until it exists, nothing in a shipping scene does, and US-0043 says
## so rather than implying otherwise.
func joinable_group(point: Vector3) -> int:
	return _formations.joinable_group(point, Tuning.suspicion.blend_group_join_radius)


func claim_slot(peer: int, group: int) -> bool:
	return _formations.claim(peer, group)


## Called on leaving the blend **and on disconnect**: ENet reuses peer ids, so a
## slot left held is a slot the next joiner inherits.
func release_slot(peer: int) -> void:
	_formations.release(peer)


## Where `peer` must stand to keep the blend, or `Vector3.INF`.
func slot_position_of(peer: int) -> Vector3:
	return _formations.slot_position_of(peer)


## The formations themselves, for tests and for US-0047's clone redistribution.
func formations() -> CrowdFormations:
	return _formations


## Layer 4's own bookkeeping, for the tests that ask whether it did anything.
func clones() -> CloneBalance:
	return _clones


## Stand the four processions up. Called once, **after** the crowd is placed:
## `server_root.gd` does it at the end of `_place_the_crowd`.
func form_groups() -> void:
	if _pool != null:
		_formations.form(_pool)


## **VIOLENCE HAPPENED HERE.** `SYS-KILL` and `SYS-STUN` call this at M4;
## `Whisperbolt` will too. Returns how many NPCs it startled, across both hops.
##
## **NOTHING IN A SHIPPING SCENE CALLS IT YET** — kill and stun are M4 — and
## US-0044 says so rather than implying otherwise. The *sprinting* half of the
## same mechanic is fully wired and runs every second.
##
## **IT QUERIES THIS TICK'S GRID, SO IT MUST BE CALLED AFTER ONE.** `_reindex`
## rebuilds the shared hash at the top of the `crowd` stage; called before the
## first tick of a match it finds an empty grid and startles nobody, silently.
## That is safe in production for a reason worth stating rather than relying on:
## `SYS-KILL` and `SYS-STUN` resolve at the `combat` stage, which `SystemOrder`
## puts four positions *after* `crowd`.
func startle_at(origin: Vector3, radius: float = -1.0) -> int:
	if _pool == null or _hash == null:
		return 0
	var reach := radius if radius > 0.0 else Tuning.crowd.startle_radius_violence
	return _alarm.startle_at(origin, reach, _hash, _pool)


## Put a body on the ground and send the crowd to look at it. `SYS-KILL`'s, at M4.
func register_corpse(where: Vector3, tick: int, victim_peer: int = 0) -> Corpse:
	if _pool == null or _hash == null:
		return null
	var corpse := Corpse.at(where, tick, victim_peer)
	_corpses.add(corpse, _hash, _pool)
	return corpse


## The alarm and the register, for tests and for the systems that will drive them.
func alarm() -> CrowdAlarm:
	return _alarm


func corpses() -> CorpseRegister:
	return _corpses
