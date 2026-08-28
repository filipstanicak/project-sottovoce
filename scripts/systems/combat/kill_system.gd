## **`SYS-KILL`.** TDD-10 §3, ADR-0010, GDD-02 §3, US-0060. SERVER ONLY.
##
## Ticks at the `combat` stage, which `SystemOrder` puts **before `contract`** so
## the cycle is repaired in the same tick a death resolves and nobody is
## contractless at a tick boundary.
##
## **THE DECISIONS ARE PURE AND THIS IS THE SEQUENCING.** `KillRules` answers
## whether a press lands, against a `RewoundWorld` and nothing else; `KillContest`
## answers who was first; `RewindClamp` answers how far back to look. What is left
## here is the order they are asked in, the 1.4 s the killer is committed for, and
## what happens at the contact frame.
##
## **NOTHING HERE TELLS ANOTHER SYSTEM ANYTHING.** The corpse, the startle, the
## broken blend, the contract repair and the witness penalty are all consequences
## owned by other systems, and they arrive through `killed`, wired in
## `server_root` — the shape `ContractSystem.contract_issued` already uses. A
## combat system that reached into the crowd director would make the pair
## untestable apart and would put the crowd's rules on the far side of a stage
## boundary from the crowd.
class_name KillSystem
extends GameSystem

## A kill landed, at the contact frame. `at` is where the victim fell.
signal killed(killer: int, victim: int, at: Vector3)

## A press did not land. Carries the reason, because the whiff is the only
## feedback a rejected kill gets — GDD-02 §9 failure mode 7.
signal kill_rejected(killer: int, verdict: int, target: int)

## Two initiations, one victim, and this one lost. The loser is staggered for
## `TUN-KILL-CONTEST-STAGGER` and scores nothing. `TEL-CONTEST-RESOLVED`'s server
## half.
signal contest_resolved(loser: int, victim: int)

## **WHO WAS FIRST**, by server receive order. Public so the wiring and the tests
## can read it; it holds no rule of its own.
var contest := KillContest.new()

## **`SYS-STUN`, OWNED AND TICKED HERE.** US-0061. TDD-01 §4's box 7 is a single
## node reading *"Kill / Stun"* and `MatchDirector` permits one system per stage,
## so the stun is a plain object this system sequences rather than a second
## `GameSystem` — `SuspicionSystem`/`BlendSystem`'s shape, for the same reason.
##
## **THE ORDER IS THE RULE.** This system judges its presses first, so a hunter and
## their prey pressing in the same tick resolve for the hunter: ADR-0013's
## contested initiation, expressed as sequencing rather than as a comment.
var stun := StunSystem.new()

## `MatchContext`'s own, adopted in `setup()`. The stagger this system writes for
## a contest loser and the exile `SYS-STUN` writes for a stunned hunter live in
## one place, because both gate the same question: may this player initiate?
var lockouts: CombatLockouts = null

## **THE LINE-OF-SIGHT PREDICATE, BOUND BY `server_root` (ADR-0015).** Injected
## because neither end may reach the other: `KillRules` is pure Core and `has_los`
## is `SYS-DETECTION`'s single ray site, so a copy would be a second one. The
## binding **lifts both points to `DetectionSystem.sight_point`** — a foot-to-foot
## ray hits the floor. Unbound it answers *nothing blocks*, which is
## `_clear_of_geometry`'s own answer with no world;
## `test_sight_is_wired_into_the_kill.gd` is what stops that shipping.
var sight: Callable = Callable()

## **WHAT A KILL IS WORTH.** Bound by `server_root`, like `sight`. Null is legal
## and means an unscored match, which is what every combat fixture written before
## US-0065 gets — the alternative is a hundred tests that must stand a score log up
## to press a button.
var scoring: KillScoring = null

## Rewinds performed since the match began. ADR-0010 allows two call sites in the
## whole project; the counter makes "how often" answerable rather than assumed.
var rewinds: int = 0

## Presses judged and presses that landed — a rejection rate nobody can read is a
## feel problem nobody can diagnose.
var presses_judged: int = 0
var kills_landed: int = 0

var _ctx: MatchContext

## peer -> the buttons that peer's last applied command held. **This system's own
## edge detection**, not `PawnContext.held_buttons`: that field is rewritten
## inside `step()` at 60 Hz, so by the time the `combat` stage runs it already
## equals this tick's buttons and every press reads as held.
var _held: Dictionary = {}

## `[peer, ordinal]` per press received this tick, resolved in arrival order.
var _requests: Array = []

## killer -> `[victim, contact_tick]` for a kill in flight.
var _pending: Dictionary = {}


func stage() -> StringName:
	return &"combat"


func setup(ctx: MatchContext) -> void:
	_ctx = ctx
	lockouts = ctx.lockouts
	stun.setup(ctx)


## Connected to `MatchDirector.input_applied` in `server_root`, the same signal
## `PawnHost` is driven by. Once per received command, at the input rate.
func report_input(peer: int, command: InputCommand, _dt: float) -> void:
	var previous := int(_held.get(peer, InputBits.NONE))
	_held[peer] = command.buttons
	if InputBits.newly_pressed(command.buttons, previous) & InputBits.KILL == 0:
		return
	# **THE ORDINAL IS STAMPED WHERE ARRIVAL HAPPENS**, in `MatchDirector`. A
	# command that never went through the queue carries -1 and sorts first, which is
	# the only order a hand-built command can have.
	_requests.append([peer, command.received_ordinal])


## The stun's doorway, forwarded rather than wired separately in `server_root`.
## One `input_applied` connection for the whole combat stage keeps the two systems
## reading the same command in the same order.
func report_stun_input(peer: int, command: InputCommand, _dt: float) -> void:
	stun.report_input(peer, command)


## **THERE IS NO `report_interrupt`, AND THE ABSENCE IS THE RULE.** ADR-0013: a
## committed kill completes, so `SYS-STUN` has nothing to call. The method existed
## for one PR, was tested with no caller, and is deleted rather than left as a
## no-op — a cancel entry point that silently does nothing is worse than none,
## because the next reader wires a stun to it and believes the save landed.
##
## A killer can still fail to land: `_still_committed` checks they are in the
## animation at the contact frame, which a **third party's** kill (FATAL) breaks.
func forget(peer: int) -> void:
	_held.erase(peer)
	stun.forget(peer)
	if lockouts != null:
		lockouts.forget(peer)
	if _pending.has(peer):
		contest.release(int((_pending[peer] as Array)[0]))
		_pending.erase(peer)
	contest.forget(peer)
	for killer: int in _pending.keys():
		if int((_pending[killer] as Array)[0]) == peer:
			_pending.erase(killer)


## **CONTACT FRAMES FIRST, THEN NEW PRESSES.** A victim who dies this tick must
## not be claimable by somebody else's press in the same tick, and resolving the
## presses first would let exactly that through for one tick.
## **AND THE STUN RESOLVES AFTER BOTH**, which is where ADR-0013's contested
## initiation is decided: a hunter who pressed kill this tick is already in
## `KillAnim` by the time their prey's press is judged, and `SYS-STUN` refuses it.
func tick(ctx: MatchContext, _dt: float) -> void:
	_resolve_contact_frames(ctx)
	_resolve_requests(ctx)
	stun.tick(ctx)
	KillReadiness.publish(ctx, lockouts, sight, _is_busy)


func teardown() -> void:
	contest.clear()
	stun.teardown()
	if lockouts != null:
		lockouts.clear()
	_held.clear()
	_requests.clear()
	_pending.clear()


## Would a press right now land? **The answer lives in `KillReadiness`** — this is
## the door four combat tests already knock on, and moving a public question out
## from under its callers would be a rename wearing a refactor's clothes.
func ready_for(peer: int, ctx: MatchContext) -> bool:
	return KillReadiness.of(peer, ctx, lockouts, sight, _is_busy)


func pending_count() -> int:
	return _pending.size()


func _resolve_requests(ctx: MatchContext) -> void:
	if _requests.is_empty():
		return
	_requests.sort_custom(_by_arrival)
	for request: Array in _requests:
		_judge_one(ctx, int(request[0]), int(request[1]))
	_requests.clear()


static func _by_arrival(a: Array, b: Array) -> bool:
	return int(a[1]) < int(b[1])


func _judge_one(ctx: MatchContext, peer: int, ordinal: int) -> void:
	presses_judged += 1
	var outcome := _verdict_for(ctx, peer)
	var verdict: KillVerdict.V = outcome[0]
	var target := int(outcome[1])
	if not KillVerdict.is_allowed(verdict):
		_reject(ctx, peer, verdict, target)
		return
	if not contest.claim(target, peer, ctx.tick, ordinal):
		_stagger(ctx, peer, target)
		return
	_begin(ctx, peer, target)


## TDD-10 §3's gates, in the flowchart's own order: the cloud first, then the
## rewind, then the rules.
func _verdict_for(ctx: MatchContext, peer: int) -> Array:
	if _is_busy(ctx, peer):
		return [KillVerdict.V.BUSY, ContractCycle.NOBODY]
	var at_tick := RewindClamp.tick_for(ctx.tick, Net.rtt_ms(peer))
	var world := _rewind(ctx, peer, at_tick)
	var here := world.position_of(peer)
	# **THE CASTER'S OWN CLOUD COUNTS.** An area denial that exempted whoever threw
	# it would be a kill setup rather than a denial.
	if here != Vector3.INF and ctx.cinderfall.contains_at(here, at_tick):
		return [KillVerdict.V.IN_CINDERFALL, ContractCycle.NOBODY]
	var contract := int(ctx.announced_contracts.get(peer, ContractCycle.NOBODY))
	# **THE EXILE IS CHECKED BEFORE THE GEOMETRY AND AFTER THE REWIND**, so a
	# locked-out hunter is refused for the reason that is true rather than for
	# being out of range by a centimetre. `TUN-STUN-LOCKOUT` is what makes a stun
	# counterplay instead of a four-second delay (GDD-03 §10.2).
	if lockouts != null and lockouts.is_exiled(peer, contract, ctx.tick):
		return [KillVerdict.V.LOCKED_OUT, contract]
	# **`TUN-RESPAWN-INVULN`, checked against the CONTRACT rather than the killer.**
	# A player still in `Respawning` is already refused by `_living_others`; this is
	# the second after that, when they are back in `Idle` and standing somewhere
	# they did not choose.
	if lockouts != null and lockouts.is_protected(contract, ctx.tick):
		return [KillVerdict.V.TARGET_PROTECTED, contract]
	if CombatTargets.is_concealed(ctx.pawn_contexts.get(contract)):
		return [KillVerdict.V.TARGET_CONCEALED, contract]
	return KillRules.resolve(world, peer, contract, _living_others(ctx, peer), Tuning.combat, sight)


## **ONE OF THE TWO PLACES IN THIS PROJECT THAT REWINDS**, ADR-0010's compliance
## line; `SYS-STUN` is the other. The radius is TDD-04 §8.3's optimisation — every
## entity a kill could involve is inside `TUN-CINDERFALL-RADIUS + TUN-KILL-RANGE`
## of the attacker, which is under ten rather than ninety-six.
func _rewind(ctx: MatchContext, peer: int, at_tick: int) -> RewoundWorld:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if pawn == null:
		return RewoundWorld.new()
	rewinds += 1
	return ctx.lag_comp.rewind(at_tick, pawn.position, _rewind_radius())


## Derived from two tunables rather than written as 7.5, so retuning either moves
## it. It uses the *reach* rather than the bare range, so the validation grace
## cannot fall outside the radius that was gathered for it.
func _rewind_radius() -> float:
	var cloud := 0.0
	if Tuning.profile != null:
		var data := Tuning.profile.abilities.get(Ids.ABIL_CINDERFALL) as AbilityData
		cloud = data.radius if data != null else 0.0
	return cloud + KillRules.reach(Tuning.combat)


func _living_others(ctx: MatchContext, peer: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for other: int in ctx.pawn_contexts.keys():
		if other == peer:
			continue
		if CombatTargets.is_dead(ctx.pawn_contexts[other] as PawnContext):
			continue
		out.append(other)
	return out


## Already killing, dead, stunned, or serving a contest stagger. **Costs nothing**
## — the press was never going to be heard, and charging for it would let a
## stagger compound itself.
func _is_busy(ctx: MatchContext, peer: int) -> bool:
	if _pending.has(peer):
		return true
	if lockouts != null and lockouts.is_staggered(peer, ctx.tick):
		return true
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if pawn == null:
		return true
	if pawn.state_id == PawnStateId.KILL_ANIM or pawn.state_id == PawnStateId.STUNNED:
		return true
	if pawn.state_id == PawnStateId.STUN_ANIM:
		return true
	return CombatTargets.is_dead(pawn)


func _reject(ctx: MatchContext, peer: int, verdict: KillVerdict.V, target: int) -> void:
	if KillVerdict.costs_suspicion(verdict) and Tuning.combat.invalid_target_penalty:
		_impulse(ctx, peer, Tuning.suspicion.gain_failed_kill)
	if KillVerdict.plays_a_whiff(verdict):
		kill_rejected.emit(peer, verdict, target)


## The contest loser. **No points, no lockout, and no suspicion** — losing a race
## should cost tempo and nothing else (`TUN-KILL-CONTEST-STAGGER`).
func _stagger(ctx: MatchContext, peer: int, victim: int) -> void:
	if lockouts != null:
		lockouts.stagger(peer, ctx.tick + maxi(Tuning.ticks(&"TUN-KILL-CONTEST-STAGGER"), 1))
	contest_resolved.emit(peer, victim)


## **THE BONUSES ARE CAPTURED HERE AND PAID AT THE CONTACT FRAME**, because
## GDD-07 §3 judges every one of them at the moment the player committed. The
## pending row already spans exactly that 0.9 s, so it carries them.
func _begin(ctx: MatchContext, killer: int, victim: int) -> void:
	var contact := ctx.tick + maxi(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY"), 1)
	var facts: KillScoreFacts = null
	if scoring != null:
		facts = scoring.facts_at(ctx, killer, victim)
	_pending[killer] = [victim, contact, facts]
	_enter(ctx, killer, PawnStateId.KILL_ANIM, PawnState.PRIORITY_COMBAT)


## **THE CONTACT FRAME.** `TUN-KILL-CORPSE-SPAWN-DELAY` 0.9 s of the 1.4 s
## animation, counted in NET ticks here and in STEP ticks by `KillAnimState` — two
## clocks measuring the same wall time, which `test_kill_contact_frame.gd` asserts
## agree rather than trusting.
func _resolve_contact_frames(ctx: MatchContext) -> void:
	for killer: int in _pending.keys():
		var row: Array = _pending[killer]
		if ctx.tick < int(row[1]):
			continue
		_pending.erase(killer)
		var victim := int(row[0])
		contest.release(victim)
		if not _still_committed(ctx, killer):
			# Stunned or killed before the contact frame. The save landed.
			continue
		_land(ctx, killer, victim)
		if scoring != null and row.size() > 2 and row[2] != null:
			scoring.pay_for_kill(ctx, row[2] as KillScoreFacts)


## Is the killer still in the animation they started?
##
## **ONLY A THIRD PARTY CAN TAKE THEM OUT OF IT** as of ADR-0013 — `KillAnimState`
## declines every COMBAT-priority request, so a stun no longer saves the victim
## and this is a FATAL-priority check in all but name.
func _still_committed(ctx: MatchContext, killer: int) -> bool:
	var pawn: PawnContext = ctx.pawn_contexts.get(killer)
	return pawn != null and pawn.state_id == PawnStateId.KILL_ANIM


func _land(ctx: MatchContext, killer: int, victim: int) -> void:
	var pawn: PawnContext = ctx.pawn_contexts.get(victim)
	if pawn == null or CombatTargets.is_dead(pawn):
		return
	var at := pawn.position
	_enter(ctx, victim, PawnStateId.DEAD, PawnState.PRIORITY_FATAL)
	kills_landed += 1
	killed.emit(killer, victim, at)


## Put a pawn into a state through its own machine, so the graph validates the
## edge rather than the caller assuming it.
##
## **AN ILLEGAL EDGE IS REPORTED, NOT ASSERTED AWAY.** GDD-02 §3's normative
## diagram has no `Drop -> Dead` and no `StunAnim -> Dead`, so a player killed
## while falling or mid-stun-swing cannot enter `Dead` at all. That is a gap in the
## diagram rather than in this code; the death still resolves, and the pawn keeps
## walking.
func _enter(ctx: MatchContext, peer: int, to: StringName, priority: int) -> bool:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	var machine: PawnStateMachine = ctx.pawn_machines.get(peer)
	if pawn == null or machine == null:
		return false
	if not machine.is_valid_edge(pawn.state_id, to):
		Log.warn("no %s -> %s edge in GDD-02 §3" % [pawn.state_id, to], &"pawn")
		return false
	return machine.transition(pawn, to, priority)


## Suspicion is `SYS-SUSPICION`'s to hold; this only queues. The queue lives on a
## system rather than on `PawnContext`, because that object is replayed during
## prediction reconciliation and would walk the queue once per replayed command.
func _impulse(ctx: MatchContext, peer: int, points: float) -> void:
	if ctx.impulses != null:
		ctx.impulses.queue(peer, points)
