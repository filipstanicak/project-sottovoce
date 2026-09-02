## **`SYS-STUN`.** TDD-10 §4, GDD-03 §10, ADR-0010, US-0061. SERVER ONLY.
##
## **NOT A `GameSystem`, AND TDD-01 §4's DIAGRAM DECIDED THAT.** `MatchDirector`
## permits one system per stage, and box 7 of that diagram is a single node
## reading **"Kill / Stun — lag-comp rewind, contest resolve"**. So this is a
## plain object `KillSystem` owns and ticks, exactly as `SuspicionSystem` owns
## `BlendSystem` for the same reason (TDD-07 §3.1.1). A new `stun` stage was
## considered and rejected: it would amend a normative diagram six documents
## reference, in order to express an ordering that diagram already expresses.
##
## **THE KILL RESOLVES FIRST WITHIN A TICK, AND THAT IS ADR-0013 FALLING OUT OF
## THE ORDERING RATHER THAN A COMMENT.** `KillSystem.tick` judges its presses,
## then calls this. So a hunter and their prey who press in the *same* tick
## resolve for the hunter — the reference's rule for a contested initiation, and
## GDD-03 §10.1.1's table read at its narrowest moment. The prey's window is the
## whole approach, not the instant.
##
## **THE TARGET IS ALWAYS THE STUNNER'S OWN PURSUER**, found by reverse lookup on
## the *announced* contracts. The graph's would be wrong in the one direction that
## matters: during `TUN-CONTRACT-REASSIGN-DELAY` a killer has been told nothing,
## so nobody may stun them for something they have not been asked to do.
class_name StunSystem
extends RefCounted

## A stun landed. `lockout_ticks` is how long the pursuer is exiled from this
## target, which both parties are told — see `CombatLockouts.remaining`.
signal stunned(stunner: int, target: int, lockout_ticks: int)

## A press did not land. The verdict is for telemetry and tests; **the client is
## told only `valid: false`**, because a refusal that reported its reason would be
## a free identity probe (see `StunVerdict`).
signal stun_rejected(stunner: int, verdict: int, target: int)

## Rewinds performed since the match began. ADR-0010's compliance list allows two
## call sites in the whole project and this is the second.
var rewinds: int = 0

## Published for the same reason `KillSystem`'s are: a rejection rate nobody can
## read is a feel problem nobody can diagnose.
var presses_judged: int = 0
var stuns_landed: int = 0

## `MatchContext`'s own, adopted by reference in `setup()`. **Never mirrored** —
## `SYS-KILL` reads the exile this system writes, and two dictionaries holding the
## same timers drift the first time somebody adds a write to one of them.
var lockouts: CombatLockouts = null

## peer -> the buttons that peer's last applied command held. **This system's own
## edge detection**, for `KillSystem`'s reason: `PawnContext.held_buttons` is
## rewritten inside `step()` at 60 Hz, so by the `combat` stage every press would
## read as held.
var _held: Dictionary = {}

## Peers who pressed stun this tick.
var _requests: PackedInt32Array = PackedInt32Array()

## peer -> the tick they may attempt again. `TUN-STUN-COOLDOWN`.
var _cooldown_until: Dictionary = {}


func setup(ctx: MatchContext) -> void:
	lockouts = ctx.lockouts


## Connected to `MatchDirector.input_applied` through `KillSystem`, once per
## received command at the input rate.
func report_input(peer: int, command: InputCommand) -> void:
	var previous := int(_held.get(peer, InputBits.NONE))
	_held[peer] = command.buttons
	if InputBits.newly_pressed(command.buttons, previous) & InputBits.STUN == 0:
		return
	if not _requests.has(peer):
		_requests.append(peer)


## **NO ARRIVAL ORDER HERE, UNLIKE THE KILL.** Two players cannot contest one
## stun: a stun's only legal target is the stunner's own pursuer, and the cycle
## gives every player exactly one incoming edge — so no two stunners ever share a
## target. `KillContest` has nothing to arbitrate and is not consulted.
func tick(ctx: MatchContext) -> void:
	for peer: int in _requests:
		_judge_one(ctx, peer)
	_requests.clear()
	_publish_readiness(ctx)


func forget(peer: int) -> void:
	_held.erase(peer)
	_cooldown_until.erase(peer)


func teardown() -> void:
	_held.clear()
	_requests.clear()
	_cooldown_until.clear()


## Who has been *announced* `peer` as their contract, or `ContractCycle.NOBODY`.
##
## A reverse lookup over at most six entries. The forward map is the one
## `SYS-CONTRACT` owns and the one every other system reads; keeping a reverse
## copy beside it would be a second authority on who hunts whom.
static func pursuer_of(peer: int, ctx: MatchContext) -> int:
	for hunter: int in ctx.announced_contracts.keys():
		if int(ctx.announced_contracts[hunter]) == peer:
			return hunter
	return ContractCycle.NOBODY


## `TUN-STUN-LOCKOUT` in net ticks, less `TUN-PASV-SECONDWIND-REDUCTION` if the
## stunned hunter carries the passive.
##
## **IT REDUCES THE EXILE AND NEVER THE FREEZE**, which is the passive's whole
## specification: being stunned must always be catastrophic in the moment, and
## `TUN-STUN-FREEZE` is `StunnedState`'s own duration — there is no argument
## through which this function could shorten it.
##
## Both terms come from the precomputed tick tables rather than from arithmetic on
## seconds, so the difference is exact at any tick rate.
static func lockout_ticks(has_second_wind: bool) -> int:
	var ticks := Tuning.ticks(&"TUN-STUN-LOCKOUT")
	if has_second_wind:
		ticks -= Tuning.ticks(&"TUN-PASV-SECONDWIND-REDUCTION")
	return maxi(ticks, 1)


## Would a press right now land? For the snapshot's `stun_ready` bit.
##
## **PRESENT TENSE, NOT REWOUND**, like `KillSystem.ready_for` — it is a hint drawn
## on the prey's own screen about their own position, and rewinding it would make
## the reticle disagree with what they can see.
func ready_for(peer: int, ctx: MatchContext) -> bool:
	var here: PawnContext = ctx.pawn_contexts.get(peer)
	if here == null or _is_busy(ctx, peer):
		return false
	var pursuer := pursuer_of(peer, ctx)
	if pursuer == ContractCycle.NOBODY:
		return false
	var them: PawnContext = ctx.pawn_contexts.get(pursuer)
	if them == null or not _is_a_target(them, pursuer, ctx):
		return false
	var t := Tuning.combat
	return (
		StunRules.in_reach(here.position, them.position, t)
		and StunRules.within_cone(here.position, here.yaw, them.position, t)
	)


## Everything about the *pursuer* that decides whether the hint may light.
##
## **THE TIER GATE BELONGS HERE, AND LEAVING IT OUT WAS AN ANONYMITY LEAK RATHER
## THAN A COSMETIC BUG.** `stun_ready` is drawn on the prey's own screen; lit for
## an Anonymous pursuer standing in a crowd it would say *that one is hunting
## you*, for free, with no lock and no warning — the exact identity the whole game
## withholds. Found by `test_stun_system.gd`, not by review.
func _is_a_target(them: PawnContext, pursuer: int, ctx: MatchContext) -> bool:
	if not _is_stunnable(them) or them.state_id == PawnStateId.KILL_ANIM:
		return false
	if them.tier < _floor_tier() or them.blend_state == BlendKind.Kind.PROP_CONCEAL:
		return false
	return lockouts == null or not lockouts.is_protected(pursuer, ctx.tick)


func _publish_readiness(ctx: MatchContext) -> void:
	for peer: int in ctx.pawn_contexts.keys():
		(ctx.pawn_contexts[peer] as PawnContext).stun_ready = ready_for(peer, ctx)


func _judge_one(ctx: MatchContext, peer: int) -> void:
	presses_judged += 1
	var outcome := _verdict_for(ctx, peer)
	var verdict: StunVerdict.V = outcome[0]
	var target := int(outcome[1])
	if verdict != StunVerdict.V.BUSY:
		_arm_cooldown(ctx, peer)
	if not StunVerdict.is_allowed(verdict):
		_reject(ctx, peer, verdict, target)
		return
	_land(ctx, peer, target)


## TDD-10 §4's gates. **The tier gate is asked before the geometry**, because it
## is one comparison and the rewind is not — and because it is the gate the design
## leans on: an Anonymous hunter is unstunnable at any range.
func _verdict_for(ctx: MatchContext, peer: int) -> Array:
	if _is_busy(ctx, peer):
		return [StunVerdict.V.BUSY, ContractCycle.NOBODY]
	var pursuer := pursuer_of(peer, ctx)
	var them: PawnContext = ctx.pawn_contexts.get(pursuer)
	if them != null and them.state_id == PawnStateId.KILL_ANIM:
		return [StunVerdict.V.TARGET_COMMITTED, pursuer]
	if CombatTargets.is_concealed(them):
		return [StunVerdict.V.TARGET_CONCEALED, pursuer]
	if lockouts != null and pursuer != ContractCycle.NOBODY:
		if lockouts.is_protected(pursuer, ctx.tick):
			return [StunVerdict.V.TARGET_PROTECTED, pursuer]
	if them != null and them.tier < _floor_tier():
		return [StunVerdict.V.TOO_CALM, pursuer]
	var at_tick := RewindClamp.tick_for(ctx.tick, Net.rtt_ms(peer))
	var world := _rewind(ctx, peer, at_tick)
	return StunRules.resolve(world, peer, pursuer, _stunnable_others(ctx, peer), Tuning.combat)


## The tier a pursuer must reach, resolved from `TUN-STUN-MIN-TIER` rather than
## written as `!= ANONYMOUS`. Invariant §17.8 pins it equal to the warn floor, so
## the two cannot separate today — the derivation is what keeps that true if one
## of them ever moves.
static func _floor_tier() -> int:
	return SuspicionMath.evaluate_tier(
		Tuning.combat.stun_min_tier, SuspicionMath.Tier.ANONYMOUS, Tuning.suspicion
	)


## **THE SECOND OF THE TWO PLACES IN THIS PROJECT THAT REWINDS**, ADR-0010's
## compliance line. The radius is the reach and nothing more: unlike a kill, no
## cinder cloud gates a stun, so there is no cloud to gather.
func _rewind(ctx: MatchContext, peer: int, at_tick: int) -> RewoundWorld:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if pawn == null:
		return RewoundWorld.new()
	rewinds += 1
	return ctx.lag_comp.rewind(at_tick, pawn.position, StunRules.reach(Tuning.combat))


## Every other player a swing could connect with.
##
## **AN ALREADY-STUNNED PLAYER IS NOT ONE.** `StunnedState` declines every
## COMBAT-priority request, so a second stun would fail to change their state
## while still extending the exile — a punishment that half-applied. Swinging at
## somebody already down therefore reads as a miss, and misses cost.
func _stunnable_others(ctx: MatchContext, peer: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for other: int in ctx.pawn_contexts.keys():
		if other == peer:
			continue
		if _is_stunnable(ctx.pawn_contexts[other] as PawnContext):
			out.append(other)
	return out


static func _is_stunnable(pawn: PawnContext) -> bool:
	return (
		pawn.state_id != PawnStateId.DEAD
		and pawn.state_id != PawnStateId.RESPAWNING
		and pawn.state_id != PawnStateId.STUNNED
	)


## Mid-swing, staggered, on cooldown, stunned or dead. **Costs nothing.**
##
## **A TARGET MID-LUNGE IS DELIBERATELY ABSENT FROM THIS LIST AND FROM
## `_is_stunnable`.** US-0061's ninth criterion asks that a player be stunnable
## for the whole of a Lunge's wind-up and dash; `ABIL-LUNGE` is M5, so there is no
## state to be in — and the way to keep the criterion true when it arrives is for
## nothing here to grow a case for it. `test_stun_refusal_set.gd` names the set.
func _is_busy(ctx: MatchContext, peer: int) -> bool:
	if ctx.tick < int(_cooldown_until.get(peer, -1)):
		return true
	if lockouts != null and lockouts.is_staggered(peer, ctx.tick):
		return true
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if pawn == null:
		return true
	if pawn.state_id == PawnStateId.STUN_ANIM or pawn.state_id == PawnStateId.KILL_ANIM:
		return true
	return not _is_stunnable(pawn)


func _arm_cooldown(ctx: MatchContext, peer: int) -> void:
	_cooldown_until[peer] = ctx.tick + maxi(Tuning.ticks(&"TUN-STUN-COOLDOWN"), 1)


## GDD-03 §10.3's anti-spam, and **the target is not affected at all** — they see
## you lunge and stumble.
##
## The stagger is longer than the 0.7 s a valid stun costs, so flailing is
## strictly worse than doing nothing: the strategy punishes itself with the thing
## it was trying to prevent.
func _reject(ctx: MatchContext, peer: int, verdict: StunVerdict.V, target: int) -> void:
	if StunVerdict.costs_the_stunner(verdict):
		var ticks := maxi(Tuning.ticks(&"TUN-STUN-INVALID-STAGGER"), 1)
		if lockouts != null:
			lockouts.stagger(peer, ctx.tick + ticks)
		# **ADR-0017.** Until this state existed, "flailing is strictly worse than
		# doing nothing" was false: the lockout blocks presses and a flailer could
		# still sprint out of the space they had just announced themselves in. Two
		# seconds of buttons is not two seconds of exposure.
		#
		# **NET TICKS ABOVE, STEP TICKS HERE** — same wall time, two domains, trap 9.
		var pawn: PawnContext = ctx.pawn_contexts.get(peer)
		if pawn != null:
			pawn.arm_stagger(Tuning.step_ticks(&"TUN-STUN-INVALID-STAGGER"))
			_enter(ctx, peer, PawnStateId.STAGGERED, PawnState.PRIORITY_COMBAT)
		if ctx.impulses != null:
			ctx.impulses.queue(peer, Tuning.combat.stun_invalid_suspicion)
	if StunVerdict.plays_a_whiff(verdict):
		stun_rejected.emit(peer, verdict, target)


## Freeze, exile, and 0.7 s of commitment for the stunner.
##
## **THE FORCED EXPOSED IS NOT SET HERE.** `TUN-STUN-FORCES-EXPOSED` is *held* at
## the maximum for the whole freeze by `SuspicionSystem`, after its integrator —
## a ceiling rather than a nudge. Setting it once from here would re-arm the decay
## delay and the punishment would start eating itself on the next tick, which is
## exactly the defect US-0053 found in `StunnedState.enter()`.
func _land(ctx: MatchContext, stunner: int, target: int) -> void:
	var exile := lockout_ticks(_has_second_wind(ctx, target))
	if lockouts != null:
		lockouts.exile(target, stunner, ctx.tick + exile)
	_enter(ctx, target, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT)
	_enter(ctx, stunner, PawnStateId.STUN_ANIM, PawnState.PRIORITY_COMBAT)
	stuns_landed += 1
	stunned.emit(stunner, target, exile)


## **`PASV-SECONDWIND` HAS NO READER, FOR `PASV-COLDREAD`'s REASON.**
## `NET-C2S-LOADOUT` is unbuilt and `PawnContext` has no passives field, so this
## answers false for everybody. `lockout_ticks` takes the flag as an argument and
## is tested both ways, so the day a loadout exists this is one call site rather
## than a rule to re-derive.
static func _has_second_wind(_ctx: MatchContext, _peer: int) -> bool:
	return false


## Put a pawn into a state through its own machine, so the graph validates the
## edge rather than this system assuming it. **An illegal edge is reported, not
## asserted away** — `KillSystem._enter`'s rule, and the same missing edges apply.
func _enter(ctx: MatchContext, peer: int, to: StringName, priority: int) -> bool:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	var machine: PawnStateMachine = ctx.pawn_machines.get(peer)
	if pawn == null or machine == null:
		return false
	if not machine.is_valid_edge(pawn.state_id, to):
		Log.warn("no %s -> %s edge in GDD-02 §3" % [pawn.state_id, to], &"pawn")
		return false
	return machine.transition(pawn, to, priority)
