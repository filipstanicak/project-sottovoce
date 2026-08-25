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
## **BLEND PROTECTS ANONYMITY, NEVER THE BODY.** There is no method here that
## refuses anything: `report_damage()` *breaks* the blend rather than absorbing
## the damage, and a blended pawn is killed and stunned exactly like any other.
## A blend that also protected the body would make patience free instead of merely
## strongest, which is design law 4 read backwards.
class_name BlendSystem
extends RefCounted

## `EVT-BLEND-STATE-CHANGED`'s server half. `kind` is a `BlendKind.Kind`; the
## client's copy arrives in the snapshot, never through this.
signal blend_changed(peer: int, kind: int)

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
		return BlendKind.Kind.NONE
	var group := _joinable_group(pawn.position, ctx)
	if group >= 0 and ctx.formations.claim(peer, group):
		record.enter(BlendKind.Kind.GROUP, group)
		_announce(peer, record)
		return BlendKind.Kind.GROUP
	if _pocket_holds(pawn.position, ctx):
		record.enter(BlendKind.Kind.POCKET, -1)
		_announce(peer, record)
		return BlendKind.Kind.POCKET
	return BlendKind.Kind.NONE


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
	match record.kind:
		BlendKind.Kind.POCKET:
			return not _pocket_holds(pawn.position, ctx)
		BlendKind.Kind.GROUP:
			return not _slot_holds(peer, pawn, ctx)
	return false


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
	record.clear()


## **THE GRACE ARMS ON ANY EXIT FROM `HELD`, INCLUDING A BREAK.** The alternative —
## only a deliberate exit qualifies — hands a hunter a way to deny the bonus by
## sprinting past a pocket, which rewards the reckless approach the whole design
## is built to charge for. A player who was blended a second ago was blended.
func _arm_grace(record: BlendRecord) -> void:
	record.grace_ticks = Tuning.ticks(&"TUN-BLEND-SCORE-GRACE")


func _announce(peer: int, record: BlendRecord) -> void:
	blend_changed.emit(peer, record.wire_kind())
