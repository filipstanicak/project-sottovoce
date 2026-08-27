## **`SYS-SPAWN`.** TDD-10 §6, GDD-05 §2.7, GDD-02 §3, US-0062. SERVER ONLY.
##
## **NOT A `GameSystem`, AND TDD-01 §4's DIAGRAM DECIDED THAT — AGAIN.**
## `MatchDirector` permits one system per stage and that diagram has **no spawn
## box at all**: its ten stages end `7. Kill / Stun`, `8. Contract — repair cycle
## after deaths`, `9. Score`. A respawn *is* a repair after a death, so this is a
## plain object `ContractSystem` owns and ticks at stage 8 —
## `SuspicionSystem`/`BlendSystem` and `KillSystem`/`StunSystem`'s shape, for the
## third time. A new stage would amend a normative diagram six documents
## reference.
##
## **AND THE ORDER INSIDE THAT STAGE IS THE RULE.** `ContractSystem.tick` calls
## this **first**, so a player whose timer expires is placed and reinserted into
## the cycle in the **same tick** — never a tick in which they exist on the map
## and hold no contract.
##
## **THE SPAWN POINT IS CHOSEN WHEN THE TIMER EXPIRES, NEVER WHEN THE PLAYER
## DIED.** Five seconds is long enough for the whole lobby to move, and a point
## chosen at the contact frame would satisfy GDD-05 §2.7 rule 3 against a world
## that no longer exists.
class_name SpawnSystem
extends RefCounted

## A player is back on the map. `at` is where they were put; `killer` is who put
## them there, or `ContractCycle.NOBODY`.
signal respawned(peer: int, at: Vector3, killer: int)

## Players placed since the match began, and how many of those took rule 7's
## fallback because the constraints were unsatisfiable. **Published rather than
## logged**: a lobby in which every respawn falls back is one where the anti-camp
## analysis has stopped holding, and that is a number somebody can read.
var placements: int = 0
var fallbacks: int = 0

## `MatchContext`'s own, adopted in `setup()`. `SYS-SPAWN` writes the invulnerable
## window; `SYS-KILL` and `SYS-STUN` read it. Never mirrored.
var lockouts: CombatLockouts = null

## peer -> `[tick_they_may_return, killer]`.
var _due: Dictionary = {}


func setup(ctx: MatchContext) -> void:
	lockouts = ctx.lockouts


## A death resolved. Connected to `KillSystem.killed` in `server_root`, the same
## signal that registers the corpse — which is what makes GDD-02 §3's
## `Dead --> Respawning: corpse spawned` edge true rather than approximately true.
func report_death(victim: int, killer: int, ctx: MatchContext) -> void:
	_due[victim] = [ctx.tick + delay_ticks(), killer]


## `TUN-RESPAWN-DELAY` in **net** ticks. Trap 9: this system ticks at 30 Hz, and
## `step_ticks` would give a 2.5 s death.
static func delay_ticks() -> int:
	return maxi(Tuning.ticks(&"TUN-RESPAWN-DELAY"), 1)


## `TUN-RESPAWN-INVULN` in net ticks.
static func invuln_ticks() -> int:
	return maxi(Tuning.ticks(&"TUN-RESPAWN-INVULN"), 1)


func tick(ctx: MatchContext) -> void:
	for peer: int in _due.keys():
		var row: Array = _due[peer]
		_enter_respawning(ctx, peer)
		if ctx.tick < int(row[0]):
			continue
		_due.erase(peer)
		_place(ctx, peer, int(row[1]))


## The `Dead --> Respawning` edge, taken on the tick the death resolves and
## harmless on every tick after it — a pawn already in `Respawning` is not a legal
## `from`, so the machine refuses and nothing happens.
##
## **AN ILLEGAL EDGE IS REPORTED, NOT ASSERTED PAST**, exactly as
## `KillSystem._enter` does: GDD-02 §3's diagram has no `Drop -> Dead` and no
## `StunAnim -> Dead`, so a player killed while falling never reached `Dead` and
## will not reach `Respawning` either. The timer still runs and they are still
## placed; what they lose is the five seconds of being untargetable.
func _enter_respawning(ctx: MatchContext, peer: int) -> void:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if pawn == null or pawn.state_id != PawnStateId.DEAD:
		return
	_complete(ctx, peer, PawnStateId.RESPAWNING)


## Choose, place, protect, reinsert.
func _place(ctx: MatchContext, peer: int, killer: int) -> void:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if pawn == null:
		return
	var points := _points(ctx)
	var killer_at := _position_of(ctx, killer)
	# **ONE READING OF THE LOBBY, USED TWICE.** Asking twice would let the two
	# answers disagree if anything moved between them, and the count below is
	# supposed to describe the choice that was actually made.
	var others := _living_others(ctx, peer)
	var index := SpawnRules.choose(points, killer_at, others, _t(), ctx.rng)
	if index < 0:
		Log.error("SYS-SPAWN: the map declares no spawn points", &"pawn")
		return
	if SpawnRules.candidates(points, killer_at, others, _t()).is_empty():
		fallbacks += 1
	var at := points[index]
	pawn.reset_for_spawn(at, 0.0)
	# **`TUN-RESPAWN-SUSPICION` GETS ITS FIRST READER HERE.** `reset_for_spawn`
	# writes a literal `0.0`, which agrees with the tunable and is not reading it —
	# so retuning the value would have changed nothing anywhere. Written after the
	# reset so the tunable is the last word.
	pawn.suspicion = _t().suspicion
	if pawn.body != null:
		pawn.body.global_position = at
	_complete(ctx, peer, PawnStateId.IDLE)
	if lockouts != null:
		lockouts.protect(peer, ctx.tick + invuln_ticks())
	placements += 1
	respawned.emit(peer, at, killer)


func _t() -> ContractTuning:
	return Tuning.contract


func _points(ctx: MatchContext) -> Array[Vector3]:
	var empty: Array[Vector3] = []
	return empty if ctx.map == null else ctx.map.spawn_points


## Every living player's position **except the one being placed**. A corpse
## standing at its own death position would otherwise veto every spawn near it.
##
## A player still in `Dead` or `Respawning` is not counted either: they are not
## targets, so spawning beside one costs nobody anything, and counting them would
## let a lobby that has just been wiped veto its own return.
func _living_others(ctx: MatchContext, peer: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for other: int in ctx.pawn_contexts.keys():
		if other == peer:
			continue
		var pawn := ctx.pawn_contexts[other] as PawnContext
		if pawn == null or _is_away(pawn):
			continue
		out.append(pawn.position)
	return out


static func _is_away(pawn: PawnContext) -> bool:
	return pawn.state_id == PawnStateId.DEAD or pawn.state_id == PawnStateId.RESPAWNING


func _position_of(ctx: MatchContext, peer: int) -> Vector3:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	return SpawnRules.NO_KILLER if pawn == null else pawn.position


## How many players are waiting to come back. For tests and for a readout.
func pending_count() -> int:
	return _due.size()


## The tick `peer` may return on, or `-1`.
func return_tick_of(peer: int) -> int:
	if not _due.has(peer):
		return -1
	return int((_due[peer] as Array)[0])


func forget(peer: int) -> void:
	_due.erase(peer)


func teardown() -> void:
	_due.clear()


## **BOTH RESPAWN EDGES ARE COMPLETIONS, NOT INTERRUPTIONS — TRAP 8.**
## `PawnStateMachine.transition` takes an `interrupting` flag and `step()` passes
## **false**, because *a state asking to leave is completion*. Gating a state's own
## exit on `is_interruptible()` is what made `Vault` and `KillAnim` permanent when
## they were first written.
##
## `Dead` and `Respawning` are both FATAL and both decline every interruption, so
## an interrupting request at FATAL priority is refused by
## `priority <= current.interrupt_priority()` and the pawn stays dead forever —
## which is what happened the first time this system ran.
##
## **THE SERVER HOLDS THESE TWO CLOCKS AND THE STATES DO NOT**, because the
## position a respawn lands at is chosen from the live lobby at the moment the
## timer expires and a client cannot know it (never-do #3). So the completion is
## requested from here rather than returned from `step()`, and the edge table is
## still what decides whether it is legal.
##
## **This is not a general bypass and must not become one.** Nothing else in
## `scripts/systems/` may complete another system's state; `SYS-KILL` and
## `SYS-STUN` both use the interrupting form, and they are asserting authority
## over a state they did not start.
func _complete(ctx: MatchContext, peer: int, to: StringName) -> bool:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	var machine: PawnStateMachine = ctx.pawn_machines.get(peer)
	if pawn == null or machine == null:
		return false
	if not machine.is_valid_edge(pawn.state_id, to):
		Log.warn("no %s -> %s edge in GDD-02 §3" % [pawn.state_id, to], &"pawn")
		return false
	return machine.transition(pawn, to, PawnState.PRIORITY_FATAL, false)
