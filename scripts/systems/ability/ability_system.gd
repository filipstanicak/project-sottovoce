## **`SYS-ABILITY`: REQUEST, VALIDATE, COMMIT, BROADCAST, TICK, END.** TDD-09,
## US-0066. SERVER ONLY, `abilities` stage.
##
## **THE REQUEST CARRIES INTENT AND NEVER AN OUTCOME.** A client sends a slot and
## an aim; every one of TDD-09 §1.1's five validations happens here, and the only
## one that can be *wrong* rather than refused is the aim — which is clamped.
##
## **THE TELL IS THE ONLY THING THAT MATTERS ON THE WIRE.** Design law 3: no
## ability resolves without the victim having had a perceivable chance to read it.
## `NET-S2C-ABILITY-STARTED` goes **reliably** to every client inside the
## ability's own tell radius, and it goes out *before* the effect begins — a tell
## that arrived after the thing it warns about would be a tell in name only.
##
## **AND THE COOLDOWN STARTS AT ACTIVATION, NEVER AT EFFECT END** (TDD-09 §2).
## Second Face lasts fifteen seconds; starting its cooldown when it expires would
## make the real interval 45 s rather than the 30 s TUNABLES publishes, and the
## number a player learns would be one no document contains.
class_name AbilitySystem
extends GameSystem

## `NET-S2C-ABILITY-STARTED`, to everybody who could perceive it.
signal ability_started(peer: int, ability: StringName, origin: Vector3, direction: Vector3)

## `NET-S2C-ABILITY-DENIED`, to the presser alone.
signal ability_denied(peer: int, slot: int, why: int)

## Two active slots, `TUN-ABILITY-SLOTS-ACTIVE`. Indexed by slot, not by ability —
## which is why adding an ability needs no new snapshot field (TDD-09 §5.1).
const SLOTS := 2

## Peer -> Array[StringName] of `ABIL-` ids, one per slot. **Bound rather than
## reached for**, like `KillSystem.sight`: `NET-C2S-LOADOUT` and the lobby are
## US-0071's, and until then `server_root` sets a default so the pipeline is
## reachable at all. An unequipped peer is refused by validation 1, which is the
## safe direction.
var loadout: Dictionary = {}

var requests_judged: int = 0
var activations: int = 0

var _ctx: MatchContext = null

## Peer -> Array[int], the tick each slot is ready again.
var _ready_at: Dictionary = {}

## Peer -> the tick anything may next be cast.
var _global_ready_at: Dictionary = {}

## Peer -> Array of [AbilityEffect, ends_at_tick, ability_id].
var _live: Dictionary = {}

## Requests received this tick, drained in `tick`.
var _pending: Array = []


func stage() -> StringName:
	return &"abilities"


func setup(ctx: MatchContext) -> void:
	_ctx = ctx


## From `RpcRouter.ability_requested`. **Queued, never judged here** — the router
## delivers on the `ingest` stage and every rule in this game is decided at its own
## stage, in `SystemOrder`'s order.
func report_request(peer: int, slot: int, origin: Vector3, direction: Vector3) -> void:
	_pending.append([peer, slot, origin, direction])


func tick(ctx: MatchContext, dt: float) -> void:
	for row: Array in _pending:
		_judge(ctx, int(row[0]), int(row[1]), row[2] as Vector3, row[3] as Vector3)
	_pending.clear()
	_advance_effects(ctx, dt)


## Ticks until this slot is ready, for the owner's own snapshot block. **Zero when
## ready**, so the HUD needs no sentinel.
func cooldown_ticks(peer: int, slot: int) -> int:
	var rows: Array = _ready_at.get(peer, [])
	if slot < 0 or slot >= rows.size() or _ctx == null:
		return 0
	return maxi(int(rows[slot]) - _ctx.tick, 0)


## Is this ability running on this player right now? **`SCORE-MASKED` reads this**
## (TDD-10 §2), and so will `SYS-KILL` for Second Face's identity swap. It answers
## honestly today and always false, because no effect exists to be active.
func is_effect_active(peer: int, ability: StringName) -> bool:
	for row: Array in _live.get(peer, []) as Array:
		if row[2] == ability:
			return true
	return false


## **COOLDOWNS RESET ON DEATH** (TDD-09 §2). Death already costs
## `TUN-RESPAWN-DELAY` and every point of `SCORE-VARIETY` progress for that life;
## carrying cooldowns through it would compound the punishment and push players
## toward passivity. The suicide-to-reroll exploit this opens is **monitored via
## `TEL-SUICIDE-SUSPECTED` rather than pre-emptively closed.**
##
## **AND IT IS NOT `PawnContext.reset_for_spawn`, WHICH IS WHERE US-0062 EXPECTED
## IT.** That object is replayed during prediction reconciliation, so a cooldown
## living there would be rewound and re-applied twenty times per correction — the
## same finding as the suspicion impulse queue and the patient speed ring.
func on_death(peer: int) -> void:
	_ready_at.erase(peer)
	_global_ready_at.erase(peer)
	_end_all(peer)


func forget(peer: int) -> void:
	on_death(peer)
	loadout.erase(peer)


func teardown() -> void:
	for peer: int in _live.keys():
		_end_all(peer)
	_ready_at.clear()
	_global_ready_at.clear()
	_pending.clear()


## One request, all the way through. **The order is TDD-09 §1.1's**: refuse, or
## commit everything — there is no half-accepted cast.
func _judge(ctx: MatchContext, peer: int, slot: int, origin: Vector3, direction: Vector3) -> void:
	requests_judged += 1
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	var ability := ability_in(peer, slot)
	var data: AbilityData = Tuning.ability_data(ability)
	var why := AbilityRules.check(
		pawn != null and data != null and ability != &"",
		ctx.tick,
		_slot_ready_at(peer, slot),
		int(_global_ready_at.get(peer, 0)),
		pawn.state_id if pawn != null else PawnStateId.DEAD
	)
	if why != AbilityDenial.Why.NONE:
		ability_denied.emit(peer, slot, why)
		return
	_commit(ctx, peer, slot, ability, data, _aim_of(pawn, data, origin, direction))


## Cooldown, cost, tell, effect — **and the tell goes out before the effect
## begins**, which is design law 3 expressed as two adjacent lines rather than as
## a comment.
func _commit(
	ctx: MatchContext, peer: int, slot: int, ability: StringName, data: AbilityData, aim: AimData
) -> void:
	activations += 1
	_start_cooldown(ctx, peer, slot, data)
	if data.suspicion_cost > 0.0:
		ctx.impulses.queue(peer, data.suspicion_cost)
	ability_started.emit(peer, ability, aim.origin, aim.direction)
	var effect := _effect_for(data)
	effect.begin(ctx, peer, aim)
	var live: Array = _live.get(peer, [])
	live.append([effect, ctx.tick + maxi(_duration_ticks(data), 1), ability])
	_live[peer] = live


## **INTEGER TICK DEADLINES, NOT FLOAT TIMERS** (TDD-09 §2, TDD-03 §4.1). A float
## countdown accumulates drift and two peers disagree about when a cooldown ended;
## a deadline is one comparison and cannot drift at all.
func _start_cooldown(ctx: MatchContext, peer: int, slot: int, data: AbilityData) -> void:
	var rows: Array = _ready_at.get(peer, [])
	while rows.size() < SLOTS:
		rows.append(0)
	rows[slot] = ctx.tick + maxi(Tuning.ticks(_cooldown_id(data)), 1)
	_ready_at[peer] = rows
	_global_ready_at[peer] = ctx.tick + maxi(Tuning.ticks(&"TUN-ABILITY-GLOBAL-COOLDOWN"), 1)


func _slot_ready_at(peer: int, slot: int) -> int:
	var rows: Array = _ready_at.get(peer, [])
	return int(rows[slot]) if slot >= 0 and slot < rows.size() else 0


## What is in this slot, or `&""`. **Slot order is the loadout's order**, so the
## HUD, the cooldown array and this all index the same way.
func ability_in(peer: int, slot: int) -> StringName:
	var kit: Array = loadout.get(peer, [])
	if slot < 0 or slot >= kit.size():
		return &""
	return kit[slot] as StringName


func _aim_of(pawn: PawnContext, data: AbilityData, origin: Vector3, direction: Vector3) -> AimData:
	return AbilityRules.aim(
		origin, direction, ProbeLayout.forward(pawn.yaw), AbilityRules.reach_of(data)
	)


## **A NULL `effect_script` IS THE MVP's HONEST STATE, NOT A FALLBACK.** All four
## `.tres` files leave it unset until US-0067 to US-0070, so what a cast produces
## today is the whole pipeline and no world change.
func _effect_for(data: AbilityData) -> AbilityEffect:
	if data.effect_script == null:
		return AbilityEffect.new()
	var made: Variant = (data.effect_script as GDScript).new()
	return made as AbilityEffect if made is AbilityEffect else AbilityEffect.new()


## An ability with no duration is instantaneous and lives exactly one tick, which
## is what gives `end()` somewhere to run.
func _duration_ticks(data: AbilityData) -> int:
	return int(round(maxf(data.duration, 0.0) * Tuning.net.server_tick))


func _advance_effects(ctx: MatchContext, dt: float) -> void:
	for peer: int in _live.keys():
		var kept: Array = []
		for row: Array in _live[peer] as Array:
			var effect := row[0] as AbilityEffect
			if ctx.tick >= int(row[1]) or not effect.tick(ctx, dt):
				effect.end(ctx)
				continue
			kept.append(row)
		if kept.is_empty():
			_live.erase(peer)
		else:
			_live[peer] = kept


## **IDEMPOTENT BY CONSTRUCTION**: the row is dropped before `end` is called, so a
## death that races an expiry cannot end the same effect twice from here — which
## is half of TDD-09 §3's requirement. The other half is the effect's own.
func _end_all(peer: int) -> void:
	var rows: Array = _live.get(peer, [])
	_live.erase(peer)
	for row: Array in rows:
		(row[0] as AbilityEffect).end(_ctx)


## The `TUN-` id for this ability's cooldown. **Derived from the `ABIL-` id**, so a
## fifth ability needs no row here — `ABIL-CINDERFALL` becomes
## `TUN-CINDERFALL-COOLDOWN`, mechanically, the way `InputActions` derives an
## action name.
func _cooldown_id(data: AbilityData) -> StringName:
	return StringName("TUN-%s-COOLDOWN" % String(data.id).trim_prefix("ABIL-"))
