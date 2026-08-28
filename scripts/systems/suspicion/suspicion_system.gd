## **`SYS-SUSPICION`. THE SERVER SYSTEM AROUND THE INTEGRATOR.** TDD-07 §1–§2,
## GDD-03 §3, US-0052. SERVER ONLY.
##
## Registered at the `suspicion` stage, which `SystemOrder` puts **after** `crowd`
## for the reason that section calls the most damaging silent failure in the game:
## `TUN-SUSPICION-GAIN-OPEN` asks whether any NPC is within
## `TUN-SUSPICION-OPEN-RADIUS`, and computing that against last tick's crowd lets
## a player accrue *alone* suspicion inside a pocket that has already re-formed.
## They believe they are hidden and are not, and nothing anywhere reports it.
##
## **THE CROWD IS ASKED THROUGH `ctx.crowd_hash`, NEVER THROUGH PHYSICS.** The
## grid is rebuilt at the top of the `crowd` stage and is this tick's by
## construction; a shape query would be a second answer to a question that already
## has one, at six queries a tick, against a world the hash was built from.
##
## **IT OWNS `SYS-BLEND` AND RESOLVES IT FIRST**, which is TDD-07 §1's diagram
## exactly: blend resolution is *step 1* of this pass, before the gain sum, because
## a held blend overrides gain and decay both. `MatchDirector` permits one system
## per stage and TDD-01 §4.1 already files blend-pocket validity under the crowd →
## suspicion boundary, so the blend is not a stage of its own — it is a pure
## collaborator this system ticks, the way `ContractSystem` owns `ContractCycle`.
##
## **THE VALUE LIVES ON `PawnContext`, NOT HERE.** The snapshot builder reads
## `pawn.suspicion`, so a copy held in this system would be a second authority —
## and a respawn zeroing one and not the other is the kind of disagreement that
## surfaces as a HUD nobody trusts. What this system keeps between ticks is the
## bookkeeping the pawn has no business carrying: how long since a gain, and what
## is owed.
class_name SuspicionSystem
extends GameSystem

## Own tier crossed a hysteresis boundary. `EVT-SUSPICION-TIER-CHANGED`'s server
## half — the client's arrives through the snapshot, never through this.
signal tier_changed(peer: int, tier: int, sources: int)

## **THE INSTANT SOURCES.** `MatchContext`'s own queue, adopted by reference in
## `setup()` so `SYS-COMBAT` and `SYS-ABILITY` can owe a player points without
## knowing anything about integration — which is what `SYS-KILL` does as of
## US-0060, for a failed kill and for a witnessed one.
##
## Public, and still the same object the context holds. A mirror would be two
## queues, one of which quietly never drains.
var impulses: SuspicionImpulses = null

## **`SYS-BLEND`, RESOLVED AT STEP 1 OF THIS PASS.** Public because `RpcRouter`
## has to hand it `INPUT-BLEND` and `SYS-KILL` will read its grace window.
var blend := BlendSystem.new()

## peer -> `SuspicionState`. Only `ticks_since_gain` survives a tick; everything
## else is re-read from the world at the top of the pass.
var _states: Dictionary = {}

## peer -> the `PawnContext` its state belongs to. **ENet reuses peer ids**, so
## identity is what says a state is stale, not the id — US-0037's lesson, applied
## before it can bite.
var _owners: Dictionary = {}


func stage() -> StringName:
	return &"suspicion"


## One pass over the pawns. Six of them, at 30 Hz.
## Dependencies arrive here rather than being looked up. The impulse queue is the
## context's, adopted rather than mirrored.
func setup(ctx: MatchContext) -> void:
	impulses = ctx.impulses


func tick(ctx: MatchContext, dt: float) -> void:
	impulses = ctx.impulses
	_release_departed(ctx)
	# **STEP 1, BEFORE ANY GAIN IS SUMMED.** A blend re-validated after the
	# integrator would crush a value the same tick's gain had already added to, and
	# a pocket that scattered would cost the player a tick of anonymity they had
	# been told they still had.
	_drain_blend_requests(ctx)
	blend.resolve(ctx)
	for peer: int in ctx.pawn_contexts.keys():
		var pawn := ctx.pawn_contexts[peer] as PawnContext
		if pawn != null and _is_in_the_world(pawn):
			_advance(peer, pawn, ctx, dt)


## Spend every `INPUT-BLEND` the pawn substep latched since the last tick.
##
## **CONSUMED HERE AND NOWHERE ELSE.** The latch is set on the press edge at 60 Hz
## by `PawnInputBuffer`; leaving it set would make one press a blend request on
## every subsequent tick, which is the held-key defect US-0093 cost an afternoon to.
func _drain_blend_requests(ctx: MatchContext) -> void:
	for peer: int in ctx.pawn_contexts.keys():
		var pawn := ctx.pawn_contexts[peer] as PawnContext
		if pawn == null or not pawn.blend_requested:
			continue
		pawn.blend_requested = false
		if _is_in_the_world(pawn):
			blend.request(peer, ctx)


## **A PLAYER WHO IS NOT IN THE WORLD IS NOT OBSERVABLE.** GDD-02 §3.1: a life
## never begins already accruing suspicion — and a corpse standing on empty ground
## would otherwise accrue `TUN-SUSPICION-GAIN-OPEN` for the whole respawn timer.
func _is_in_the_world(pawn: PawnContext) -> bool:
	return pawn.state_id != PawnStateId.DEAD and pawn.state_id != PawnStateId.RESPAWNING


## Charge `peer` for walking into a civilian. Debounced by
## `TUN-SUSPICION-GAIN-NPC-BUMP-COOLDOWN`; returns whether it landed.
##
## **NOTHING CALLS THIS, AND THE BLOCKER IS PHYSICAL.** `npc_server.tscn` and
## `pawn_server.tscn` both mask `WORLD` only, so a pawn and an NPC pass through
## each other and there is no contact of any kind to report. Charging +15 for an
## overlap the player felt nothing from would be an impulse with no tell, which
## design law 3 forbids as firmly for a cost as for an ability. Making the crowd
## solid changes how movement feels through a dense pocket and is the owner's.
func report_npc_bump(peer: int, ctx: MatchContext) -> bool:
	impulses = ctx.impulses
	return impulses.bump(peer, ctx.tick, Tuning.suspicion)


## Release everything belonging to peers who no longer hold a pawn.
func _release_departed(ctx: MatchContext) -> void:
	for peer: int in _states.keys():
		if not ctx.pawn_contexts.has(peer):
			_forget(peer)
			# **AND THE FORMATION SLOT WITH IT.** ENet reuses peer ids, so a slot
			# left claimed is one the next joiner inherits and can never release —
			# and `CrowdFormations.claim()` refuses a taken slot rather than
			# evicting, so the group would be unjoinable for the rest of the match.
			blend.forget(peer, ctx)


func _forget(peer: int) -> void:
	_states.erase(peer)
	_owners.erase(peer)
	impulses.forget(peer)


## `peer`'s bookkeeping, fresh if this is a pawn the system has not seen. Keyed by
## the context's **identity**: a peer id that came back is a different player.
func _state_for(peer: int, pawn: PawnContext) -> SuspicionState:
	if _owners.get(peer) != pawn:
		_forget(peer)
		_owners[peer] = pawn
		_states[peer] = SuspicionState.new()
	return _states[peer] as SuspicionState


## TDD-07 §1's seven steps, in its order. The two that are not this system's —
## blend validation is `SYS-BLEND`'s and tier *rendering* is `SYS-DETECTION`'s —
## are read and written respectively rather than decided here.
func _advance(peer: int, pawn: PawnContext, ctx: MatchContext, dt: float) -> void:
	var t := Tuning.suspicion
	var s := _state_for(peer, pawn)
	_read_the_world(peer, s, pawn, ctx, t)

	# **STEP 3: IMPULSES, BEFORE THE INTEGRATOR AND AT A FIXED POSITION.** They
	# also re-arm the decay delay, because `ticks_since_gain` means *ticks since
	# this player last did something suspicious* — and two players sitting at 15,
	# one from running and one from a shove, must decay identically. A decay curve
	# that carried information about how the value was earned is a channel nothing
	# in the design intends.
	var owed := impulses.drain(peer)
	if owed > 0.0:
		s.value = SuspicionMath.apply_impulse(s.value, owed, t)
		s.ticks_since_gain = 0

	# **STEPS 4 AND 5: INTEGRATE AND CLAMP.** `gained()` is asked *before*
	# integration, against the same reading the integrator is about to use.
	var earned := SuspicionMath.gained(s, t)
	s.value = SuspicionMath.integrate(s, t, dt)
	s.ticks_since_gain = 0 if earned else s.ticks_since_gain + 1
	_force_exposed_while_stunned(s, pawn, t)

	# **STEPS 6 AND 7: TIER, WITH HYSTERESIS, AND THE EVENT.**
	var previous: int = pawn.tier
	pawn.suspicion = s.value
	pawn.tier = SuspicionMath.evaluate_tier(s.value, previous, t)
	pawn.active_sources = SuspicionSources.of(s, t)
	pawn.blend_state = blend.wire_kind(peer)
	if pawn.tier != previous:
		tier_changed.emit(peer, pawn.tier, pawn.active_sources)


## **`TUN-STUN-FORCES-EXPOSED`: HELD AT THE MAXIMUM FOR THE WHOLE FREEZE**, which
## is what TUNABLES §17 asks for and `Stunned`'s own duration is. It lived in
## `StunnedState.enter()` until US-0053 and was wrong twice there: predicted code
## writing gameplay state, and a single *set* rather than a hold, so the decay it
## re-armed began eating the punishment on the next tick.
func _force_exposed_while_stunned(s: SuspicionState, pawn: PawnContext, t: SuspicionTuning) -> void:
	if pawn.state_id != PawnStateId.STUNNED or not Tuning.combat.forces_exposed:
		return
	s.value = t.max_value
	s.ticks_since_gain = 0


## Everything the integrator is allowed to know, read from this tick's world.
##
## **`SCORE-PATIENT`'s SPEED WINDOW RIDES THIS PASS** (US-0065): the same
## horizontal number, sampled at stage 4 — three stages before the kill initiation
## it is judged at. A sampler of its own at the `score` stage would answer one tick
## late, and one on `PawnContext` would be replayed twenty times by prediction.
func _read_the_world(
	peer: int, s: SuspicionState, pawn: PawnContext, ctx: MatchContext, t: SuspicionTuning
) -> void:
	# **THE PAWN OWNS THE VALUE**, so a respawn that zeroes it is honoured without
	# this system being told.
	s.value = pawn.suspicion
	s.speed_state = pawn.state_id
	s.mantling = pawn.traverse_case == TraversalResolver.Case.MANTLE
	# **THE CRUSH RUNS IN `HELD` ONLY.** Entry is 0.35 s of visible, vulnerable
	# transition and exit is 0.30 s of standing up; neither buys anonymity, or a
	# player would be paid for a commitment they have not finished making.
	s.blending = blend.is_crushing(peer)

	# **HORIZONTAL SPEED, AND THAT IS NOT A ROUNDING DETAIL.** A grounded
	# `CharacterBody3D` keeps a small downward velocity from its floor snap, which
	# is comfortably above `TUN-PASV-STILLNESS-SPEED-CEILING` 0.15 — so a speed
	# taken in three axes would disable `PASV-STILLNESS` for every standing player
	# in the game, permanently, with nothing to see. Every radius and every ceiling
	# in this design is a distance across the district rather than through it.
	s.speed = Vector2(pawn.velocity.x, pawn.velocity.z).length()

	ctx.score_windows.sample_speed(peer, s.speed, Tuning.ticks(&"TUN-SCORE-PATIENT-WINDOW"))

	# Absolute, and TUNABLES says so: it works while the street stratum is flat at
	# y = 0, and a map with varying ground level needs stratum data in `MapData`.
	s.on_roof = pawn.position.y >= t.roof_height

	# **BOUNDED AT THE RADIUS THE ANSWER IS COMPARED AGAINST.** Beyond it the query
	# returns `INF`, which is exactly what "nobody near enough to matter" means —
	# and an unbounded nearest would scan the whole crowd for the one player the
	# district is emptiest around. An NPC at *exactly* the radius is company: the
	# rule is `> open_radius`.
	s.nearest_npc_distance = ctx.crowd_hash.nearest_distance(pawn.position, t.open_radius)

	# `has_stillness` is deliberately not written. `PASV-STILLNESS` is chosen in a
	# loadout, `NET-C2S-LOADOUT` is unbuilt, and there is nowhere on `PawnContext`
	# to put a passive yet. Defaulting it here would be a decision wearing an
	# omission's clothes; leaving it alone means the day it is set, it is honoured.


func teardown() -> void:
	_states.clear()
	_owners.clear()
	if impulses != null:
		impulses.clear()
