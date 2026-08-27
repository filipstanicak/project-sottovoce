## **`SYS-BLEND`. A CONDITION RE-VALIDATED EVERY TICK, NOT A STATE YOU KEEP.**
## GDD-03 §4, TDD-07 §3, US-0053. SERVER ONLY.
##
## **IT IS STEP 1 OF THE SUSPICION PASS, NOT A STAGE OF ITS OWN**, and both
## normative documents say so: TDD-07 §1's diagram draws blend resolution inside
## the `SYS-SUSPICION` box, and TDD-01 §4.1's rationale for *crowd before
## suspicion* is already written as "`TUN-SUSPICION-GAIN-OPEN` depends on whether
## any NPC is within 6 m, **and blend-pocket validity depends on NPC positions**".
## `MatchDirector` permits one system per stage, so this is a `RefCounted` the
## suspicion system owns — the same shape as `ContractCycle` under
## `ContractSystem` and `SnapshotDelta` under `SnapshotBuilder`, and it is what
## keeps the decision askable in a test with no director present. **TDD-07 §5's
## `class_name BlendSystem extends GameSystem` is amended by this.**
##
## **A BLEND THAT SILENTLY KEEPS WORKING AFTER ITS CONDITIONS LAPSE IS THE "I
## THOUGHT I WAS HIDDEN" BUG CLASS**, and it is the one this file exists to make
## impossible. Every held blend is re-checked against **this** tick's crowd, every
## tick, and a pocket that drops below `TUN-BLEND-POCKET-MIN-NPC` ends the blend
## in the tick it drops — not on the next director pass, not when the player next
## moves.
##
## **BLEND PROTECTS ANONYMITY, NEVER THE BODY — WITH ONE STATED EXCEPTION.**
## `report_damage()` *breaks* the blend rather than absorbing the damage, and a
## blended pawn is killed and stunned exactly like any other. A blend that also
## protected the body would make patience free instead of merely strongest, which
## is design law 4 read backwards.
##
## **THE EXCEPTION IS THE CONCEALMENT PROP, AND GDD-03 §4.1.4 IS WHERE IT COMES
## FROM**, not from this file: *"cannot be broken from outside; a player inside
## cannot be killed"*. It is priced with total blindness and a fixed, learnable
## location, and it is enforced by `SYS-KILL` and `SYS-STUN` reading
## `PawnContext.blend_state` rather than by anything here refusing — the same
## direction every other rule in this file runs.
class_name BlendSystem
extends RefCounted

## `EVT-BLEND-STATE-CHANGED`'s server half. `kind` is a `BlendKind.Kind`; the
## client's copy arrives in the snapshot, never through this.
signal blend_changed(peer: int, kind: int)

## A press did not take, and **why**. US-0054's third criterion: *"refused with
## distinct feedback, not silence"*. `why` is a `BlendRefusal.Why`.
##
## **UNLIKE A REJECTED KILL, THE REASON IS SAFE TO SEND.** A prop's occupancy is
## not a secret — it is level geometry with somebody in it — so telling a player
## *"there is already somebody in there"* costs nothing and withholding it costs a
## moment of confusion with a hunter behind them.
signal blend_refused(peer: int, why: int)

## **WHO IS INSIDE WHICH CONCEALMENT PROP.** US-0054. Server-owned, never
## mirrored, and public so the wiring and the tests can read it.
var props := PropOccupancy.new()

## peer -> `BlendRecord`.
var _records: Dictionary = {}


## Everything owed to `peer`, or a fresh record.
func record_for(peer: int) -> BlendRecord:
	if not _records.has(peer):
		_records[peer] = BlendRecord.new()
	return _records[peer] as BlendRecord


## `INPUT-BLEND` arrived. Returns the kind taken, or `NONE` if nothing here was
## available — **which is not silence**: the caller can tell a refusal from a
## success, so US-0054's occupied-prop feedback has something to hang on.
##
## **A PRESS WHILE ENGAGED IS AN EXIT.** GDD-03 §4.1.4 makes `INPUT-BLEND` the
## way out of a concealment prop, and one verb that both enters and leaves is the
## only version a player can use without being told which.
func request(peer: int, ctx: MatchContext) -> int:
	var record := record_for(peer)
	if record.is_engaged():
		if record.phase != BlendRecord.Phase.LEAVING:
			record.leave()
		return BlendKind.Kind.NONE
	var pawn := ctx.pawn_contexts.get(peer) as PawnContext
	if pawn == null:
		_refuse(peer, BlendRefusal.Why.BUSY)
		return BlendKind.Kind.NONE
	var taken := _take_something(peer, pawn, ctx)
	if taken != BlendKind.Kind.NONE:
		_announce(peer, record)
	return taken


## **THE MOST SPECIFIC THING YOU ARE STANDING AT WINS, BECAUSE YOU HAD TO GO
## THERE.** GDD-03 §4.1 gives no ordering and one is needed, because a hay cart in
## a market is inside a crowd pocket and beside a stall counter at the same time.
##
## Five exact spots, then twelve exact spots, then a formation you must be 2.5 m
## of, then *anywhere at all with four NPCs*. A press at a concealment prop that
## silently took the pocket instead would spend a walk the player made
## deliberately, and they would not find out until a hunter looked at them.
func _take_something(peer: int, pawn: PawnContext, ctx: MatchContext) -> int:
	var record := record_for(peer)
	var conceal := _nearest_prop(pawn.position, ctx.map.blend_props if ctx.map != null else [])
	if conceal >= 0:
		var why := props.may_enter(peer, conceal, ctx.tick)
		if why != BlendRefusal.Why.TAKEN:
			_refuse(peer, why)
			return BlendKind.Kind.NONE
		if props.claim(peer, conceal, ctx.tick):
			record.enter(BlendKind.Kind.PROP_CONCEAL, conceal)
			return BlendKind.Kind.PROP_CONCEAL
	if _nearest_prop(pawn.position, ctx.map.static_props if ctx.map != null else []) >= 0:
		record.enter(BlendKind.Kind.PROP_STATIC, -1)
		return BlendKind.Kind.PROP_STATIC
	var group := _joinable_group(pawn.position, ctx)
	if group >= 0 and ctx.formations.claim(peer, group):
		record.enter(BlendKind.Kind.GROUP, group)
		return BlendKind.Kind.GROUP
	if _pocket_holds(pawn.position, ctx):
		record.enter(BlendKind.Kind.POCKET, -1)
		return BlendKind.Kind.POCKET
	_refuse(peer, BlendRefusal.Why.NOTHING_HERE)
	return BlendKind.Kind.NONE


## The nearest prop within reach, or -1.
##
## **THE REACH IS `TUN-BLEND-GROUP-JOIN-RADIUS`, ADOPTED RATHER THAN INVENTED.**
## GDD-03 §4.1.3 and §4.1.4 both say only *"at the prop"* and no tunable carries a
## prop radius — so rather than write a new gameplay constant (never-do #1), the
## one number the game already means by *"close enough to claim this blend"* is
## reused. **If a playtest wants them different, `TUN-BLEND-PROP-RADIUS` is a
## `TUN-` addition and therefore the owner's**; the derivation is recorded here so
## nobody has to guess which it was.
static func _nearest_prop(at: Vector3, points: Array) -> int:
	var reach := Tuning.suspicion.blend_group_join_radius
	var best := -1
	var best_distance := INF
	for i: int in points.size():
		var to: Vector3 = points[i]
		var away := Vector2(at.x - to.x, at.z - to.z).length()
		if away <= reach and away < best_distance:
			best_distance = away
			best = i
	return best


func _refuse(peer: int, why: BlendRefusal.Why) -> void:
	blend_refused.emit(peer, why)


## Damage or a stun landed. **Breaks, and does not absorb** — `TUN-BLEND-BREAK-ON-
## DAMAGE`. No caller until `SYS-KILL` (US-0060) and `SYS-STUN` (US-0061); the
## speed and crowd breaks below are live.
func report_damage(peer: int, ctx: MatchContext) -> void:
	var record := record_for(peer)
	if record.is_engaged():
		_break(peer, record, ctx)


## Release everything `peer` holds. **The formation slot especially**: ENet reuses
## peer ids, so a slot left claimed is one the next joiner inherits and can never
## release. US-0037's lesson.
func forget(peer: int, ctx: MatchContext) -> void:
	if ctx.formations != null:
		ctx.formations.release(peer)
	# **THE PROP ESPECIALLY.** A hiding spot left claimed by a peer that
	# disconnected is one nobody can ever enter again — a hiding spot that silently
	# vanishes from the map for the rest of the match.
	props.forget(peer)
	_records.erase(peer)


## **STEP 1 OF THE SUSPICION PASS.** Advance every phase and re-validate every
## held blend against this tick's crowd.
func resolve(ctx: MatchContext) -> void:
	for peer: int in _records.keys():
		if not ctx.pawn_contexts.has(peer):
			forget(peer, ctx)
	for peer: int in ctx.pawn_contexts.keys():
		var pawn := ctx.pawn_contexts[peer] as PawnContext
		if pawn != null:
			_advance(peer, pawn, ctx)


## Is `peer`'s suspicion being crushed? What `SuspicionState.blending` is set from.
func is_crushing(peer: int) -> bool:
	return _records.has(peer) and (_records[peer] as BlendRecord).is_crushing()


## What the snapshot's `blend_state:u4` carries for `peer`.
func wire_kind(peer: int) -> int:
	if not _records.has(peer):
		return BlendKind.Kind.NONE
	return (_records[peer] as BlendRecord).wire_kind()


## Ticks of `TUN-BLEND-SCORE-GRACE` left. **Read by `SYS-KILL` at initiation**, so
## the blend-then-strike play is legible rather than frame-perfect — the single
## most valuable bonus in the game must not depend on 33 ms of timing.
func grace_ticks_remaining(peer: int) -> int:
	if not _records.has(peer):
		return 0
	return (_records[peer] as BlendRecord).grace_ticks


func _advance(peer: int, pawn: PawnContext, ctx: MatchContext) -> void:
	var record := record_for(peer)
	if record.grace_ticks > 0 and not record.is_engaged():
		record.grace_ticks -= 1
	if not record.is_engaged():
		return
	if _broken_by(peer, pawn, record, ctx):
		_break(peer, record, ctx)
		return
	record.phase_ticks += 1
	match record.phase:
		BlendRecord.Phase.ENTERING:
			if record.phase_ticks >= _window(&"TUN-BLEND-ENTRY-TIME"):
				record.hold()
		BlendRecord.Phase.LEAVING:
			if record.phase_ticks >= _window(&"TUN-BLEND-EXIT-TIME"):
				_finish(peer, record, ctx)


## Everything that ends a blend without the player asking. Checked **before** the
## phase advances, so a pocket that scatters this tick ends the blend this tick.
func _broken_by(peer: int, pawn: PawnContext, record: BlendRecord, ctx: MatchContext) -> bool:
	# **HORIZONTAL SPEED**, for the reason `SYS-SUSPICION` reads it that way: a
	# grounded body carries a downward velocity from its floor snap, and a blend
	# that broke on standing still would be no blend at all.
	if Vector2(pawn.velocity.x, pawn.velocity.z).length() > Tuning.suspicion.break_on_speed:
		return true
	if pawn.state_id == PawnStateId.STUNNED:
		return true
	# **A BLEND BEING LEFT IS NO LONGER VALIDATED.** The player has stood up; the
	# crowd walking away during those 0.30 s must not turn a clean exit into a
	# break, because the two arm the grace differently.
	if record.phase == BlendRecord.Phase.LEAVING:
		return false
	return _condition_lapsed(peer, pawn, record, ctx)


## The per-kind half, split out because the guard clauses above and the four kinds
## here together exceed the six returns a function may have — and the split is the
## honest one: everything above ends *any* blend, everything here ends *this* one.
##
## **A CONCEALMENT PROP HAS NO ENTRY, AND THE ABSENCE IS THE RULE.** GDD-03
## §4.1.4: *"cannot be broken from outside"*. The only way out is the player
## pressing blend again, which `request()` turns into an exit.
func _condition_lapsed(
	peer: int, pawn: PawnContext, record: BlendRecord, ctx: MatchContext
) -> bool:
	match record.kind:
		BlendKind.Kind.POCKET:
			return not _pocket_holds(pawn.position, ctx)
		BlendKind.Kind.GROUP:
			return not _slot_holds(peer, pawn, ctx)
		BlendKind.Kind.PROP_STATIC:
			return _moving_at_all(pawn)
	return false


## **"ANY MOVEMENT INPUT BREAKS THEM"** — GDD-03 §4.1.3, and it is a stricter
## rule than the `TUN-BLEND-BREAK-ON-SPEED` every other blend uses: you may drift
## inside a crowd pocket, and you may not shift on a bench.
##
## **THE THRESHOLD IS `TUN-PASV-STILLNESS-SPEED-CEILING`, ADOPTED RATHER THAN
## INVENTED.** `PawnContext` carries no move vector — only the velocity the
## substep produced — so "any movement input" is read as "moving at all", and the
## game already owns a number for that: the speed below which `PASV-STILLNESS`
## considers a player stationary. A second constant for the same question is one
## that gets retuned alone.
##
## Horizontal, for `SYS-SUSPICION`'s reason: a grounded body carries a downward
## velocity from its floor snap, and a bench that broke on sitting still would be
## no bench at all.
static func _moving_at_all(pawn: PawnContext) -> bool:
	var speed := Vector2(pawn.velocity.x, pawn.velocity.z).length()
	return speed > Tuning.suspicion.stillness_speed_ceiling


## `TUN-BLEND-POCKET-MIN-NPC` within `TUN-BLEND-POCKET-RADIUS`, asked of the grid
## `CrowdDirector` rebuilt at the top of **this** tick.
func _pocket_holds(at: Vector3, ctx: MatchContext) -> bool:
	var found := ctx.crowd_hash.count_within(at, Tuning.suspicion.blend_pocket_radius)
	return found >= Tuning.suspicion.blend_pocket_min_npc


## The slot still exists and the player is still standing in it.
##
## **THE SLOT WALKS AND THE PLAYER KEEPS UP — NOTHING MOVES THE PAWN.** Driving a
## blended player toward their slot would put the server in charge of a position
## the client predicts, and every tick of the blend would be a reconciliation. So
## the group blend *judges* rather than steers, which is also the design: GDD-03
## §4.1.2 trades mobility for agency, and a slot that dragged you along would have
## taken the agency without charging for it.
## **THE PEER IS PASSED, NEVER READ OFF THE PAWN.** `PawnContext.peer_id` was
## declared in M1 and had **no writer anywhere in the shipped server** — it is
## fixed in `PawnHost` by this story, and relying on it here would still be wrong:
## `CrowdFormations.group_of_peer(0)` matches the first group whose `player_peer`
## is `NO_PEER`, so a peer id of zero reads as *standing in the first unclaimed
## slot*. Not an empty answer — a confidently wrong one.
func _slot_holds(peer: int, pawn: PawnContext, ctx: MatchContext) -> bool:
	if ctx.formations == null or peer == CrowdFormations.NO_PEER:
		return false
	var slot := ctx.formations.slot_position_of(peer)
	if slot == Vector3.INF:
		return false
	var away := Vector2(pawn.position.x - slot.x, pawn.position.z - slot.z).length()
	return away <= Tuning.suspicion.blend_group_slot_tolerance


func _joinable_group(at: Vector3, ctx: MatchContext) -> int:
	if ctx.formations == null:
		return -1
	return ctx.formations.joinable_group(at, Tuning.suspicion.blend_group_join_radius)


## A window in net ticks, never below one: a duration tuned under 33 ms must still
## take a tick, or `>=` would complete it on the tick it started and the entry
## window would not exist.
func _window(id: StringName) -> int:
	return maxi(Tuning.ticks(id), 1)


## Ended by the world. Arms the grace if the player ever reached `HELD`.
func _break(peer: int, record: BlendRecord, ctx: MatchContext) -> void:
	var was_held := record.phase == BlendRecord.Phase.HELD
	_release(peer, record, ctx)
	if was_held:
		_arm_grace(record)
	_announce(peer, record)


## Ended by the player, after `TUN-BLEND-EXIT-TIME`.
func _finish(peer: int, record: BlendRecord, ctx: MatchContext) -> void:
	_release(peer, record, ctx)
	_arm_grace(record)
	_announce(peer, record)


func _release(peer: int, record: BlendRecord, ctx: MatchContext) -> void:
	if record.kind == BlendKind.Kind.GROUP and ctx.formations != null:
		ctx.formations.release(peer)
	# **`TUN-BLEND-PROP-EXIT-VULN` IS ARMED BY LEAVING, INCLUDING BY BREAKING.**
	# The window exists to stop door-flickering to dodge a kill, and a break is the
	# faster way out of the two — arming it only on a deliberate exit would leave
	# the exploit open through the door it is easier to reach.
	if record.kind == BlendKind.Kind.PROP_CONCEAL:
		props.release(peer, ctx.tick)
	record.clear()


## **THE GRACE ARMS ON ANY EXIT FROM `HELD`, INCLUDING A BREAK.** The alternative —
## only a deliberate exit qualifies — hands a hunter a way to deny the bonus by
## sprinting past a pocket, which rewards the reckless approach the whole design
## is built to charge for. A player who was blended a second ago was blended.
func _arm_grace(record: BlendRecord) -> void:
	record.grace_ticks = Tuning.ticks(&"TUN-BLEND-SCORE-GRACE")


func _announce(peer: int, record: BlendRecord) -> void:
	blend_changed.emit(peer, record.wire_kind())
