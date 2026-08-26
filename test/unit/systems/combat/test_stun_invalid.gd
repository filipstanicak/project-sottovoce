## **THE ANTI-SPAM, AND THE REASON IT IS NOT MERELY A PENALTY.** GDD-03 §10.3,
## US-0061.
##
## Without it the optimal defensive play in a crowd is to stun everybody who comes
## near, on the chance one of them is your pursuer. That would be tedious, would
## look absurd, and would delete the *"is that them?"* tension the whole approach
## phase is made of.
##
## **AND EVERY REFUSAL MUST COST THE SAME AND LOOK THE SAME.** A refusal that
## reported its reason would turn the stun button into a free identity probe:
## press it at a stranger and read whether the answer means *not your pursuer* or
## *your pursuer, being careful*. That is the crowd deleted, and it is the
## property this file spends most of its assertions on.
extends GutTest

const PREY := 91
const HUNTER := 92
const STRANGER := 93

var _kills: KillSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []
var _refused: Array = []


func before_each() -> void:
	_machines.clear()
	_refused = []
	_ctx = MatchContext.new()
	_ctx.tick = 200
	_kills = KillSystem.new()
	add_child_autofree(_kills)
	_kills.setup(_ctx)
	_kills.stun.stun_rejected.connect(
		func(a: int, v: int, b: int) -> void: _refused.append([a, v, b])
	)


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


func _place(peer: int, at: Vector3, yaw: float = 0.0) -> PawnContext:
	var machine := PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		machine.register(script.new())
	_machines.append(machine)
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, yaw)
	machine.spawn_into(pawn, PawnStateId.IDLE)
	_ctx.pawn_contexts[peer] = pawn
	_ctx.pawn_machines[peer] = machine
	return pawn


func _fill_the_ring(ticks: int) -> void:
	for back: int in range(ticks, 0, -1):
		var ids := PackedInt32Array()
		var places := PackedVector3Array()
		var yaws := PackedFloat32Array()
		for peer: int in _ctx.pawn_contexts.keys():
			var pawn := _ctx.pawn_contexts[peer] as PawnContext
			ids.append(peer)
			places.append(pawn.position)
			yaws.append(pawn.yaw)
		_ctx.lag_comp.record(_ctx.tick - back, ids, places, yaws)


## **THE RING MUST BE CLEARED BEFORE IT IS REFILLED, AND THIS COST AN HOUR.**
## `LagCompHistory` is a ring and `_frame_at` returns the **first** frame it finds
## for a tick — so recording the same tick twice leaves the *stale* one winning.
## A fixture that placed a pawn, filled the ring, moved the pawn and filled again
## rewinds to where the pawn **used to be**, and every geometry assertion in the
## file is then about the wrong position. It reads as a rule that does not work.
func _settle() -> void:
	_ctx.lag_comp.clear()
	_fill_the_ring(8)


func _press(peer: int) -> void:
	var command := InputCommand.empty(1)
	command.buttons = InputBits.STUN
	_kills.report_stun_input(peer, command, MatchContext.step_dt())
	_kills.report_stun_input(peer, command, MatchContext.step_dt())


func _release(peer: int) -> void:
	_kills.report_stun_input(peer, InputCommand.empty(1), MatchContext.step_dt())


func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_fill_the_ring(1)
		_ctx.tick += 1
		_kills.tick(_ctx, MatchContext.net_dt())


## A stranger standing right in front of the prey, hunting nobody. The prey's own
## pursuer is not in the world at all.
func _a_stranger() -> void:
	_place(PREY, Vector3.ZERO)
	_place(STRANGER, Vector3(0.0, 0.0, 1.5))
	(_ctx.pawn_contexts[STRANGER] as PawnContext).tier = SuspicionMath.Tier.EXPOSED
	_settle()


## The prey's real pursuer, in reach, but Anonymous — the one case a player would
## most want to tell apart from a stranger, and the one they must not be able to.
func _a_careful_pursuer() -> void:
	_place(PREY, Vector3.ZERO)
	_place(HUNTER, Vector3(0.0, 0.0, 1.5), PI)
	_ctx.announced_contracts[HUNTER] = PREY
	_settle()


func test_flailing_at_a_stranger_costs_the_stagger_and_the_suspicion() -> void:
	_a_stranger()
	_press(PREY)
	_advance()
	assert_eq(_refused.size(), 1, "flailing at a stranger produced no whiff at all")
	assert_true(_ctx.lockouts.is_staggered(PREY, _ctx.tick), "the flail was free")
	assert_almost_eq(
		_ctx.impulses.pending(PREY),
		Tuning.combat.stun_invalid_suspicion,
		0.001,
		"TUN-STUN-INVALID-SUSPICION was not charged"
	)


func test_the_target_of_a_flail_is_not_affected_at_all() -> void:
	# GDD-03 §10.3: *they see you lunge at them and stumble*. Nothing else.
	_a_stranger()
	_press(PREY)
	_advance()
	var them := _ctx.pawn_contexts[STRANGER] as PawnContext
	assert_eq(them.state_id, PawnStateId.IDLE, "the wrong target was frozen")
	assert_eq(_ctx.impulses.pending(STRANGER), 0.0, "the wrong target was charged suspicion")
	assert_false(_ctx.lockouts.is_staggered(STRANGER, _ctx.tick), "the wrong target was staggered")


func test_flailing_at_empty_air_costs_the_same() -> void:
	# **THE CASE THE NARROW READING OF §10.3 WOULD LEAVE FREE.** Its stated case is
	# a non-pursuer, but its stated *reason* is that mashing must never be optimal
	# — and a press at nobody would be free under the narrow reading, so walking
	# with the button held would cost nothing.
	_place(PREY, Vector3.ZERO)
	_settle()
	_press(PREY)
	_advance()
	assert_true(_ctx.lockouts.is_staggered(PREY, _ctx.tick), "a press at nothing was free")
	assert_gt(_ctx.impulses.pending(PREY), 0.0, "a press at nothing cost no suspicion")


func test_a_careful_pursuer_and_a_stranger_are_indistinguishable() -> void:
	# **THE IDENTITY PROBE, REFUSED.** Both refusals must cost the same and report
	# the same thing, or the stun button becomes a way to ask *"are you hunting
	# me?"* about every person in a crowd.
	_a_stranger()
	_press(PREY)
	_advance()
	var stranger_stagger := _ctx.lockouts.stagger_remaining(PREY, _ctx.tick)
	var stranger_suspicion := _ctx.impulses.pending(PREY)
	var stranger_whiffs := _refused.size()
	before_each()
	_a_careful_pursuer()
	_press(PREY)
	_advance()
	assert_eq(
		_ctx.lockouts.stagger_remaining(PREY, _ctx.tick),
		stranger_stagger,
		"a careful pursuer costs a different stagger from a stranger — that is a free read"
	)
	assert_almost_eq(_ctx.impulses.pending(PREY), stranger_suspicion, 0.001)
	assert_eq(_refused.size(), stranger_whiffs, "the two refusals produce different whiff counts")
	assert_gt(stranger_whiffs, 0, "neither case produced a whiff; this comparison is vacuous")


func test_the_flail_stagger_is_longer_than_a_valid_swing() -> void:
	# GDD-03 §10.3's own argument: flailing must be *strictly worse than doing
	# nothing*, so the punishment for missing exceeds the commitment for landing.
	assert_gt(
		Tuning.combat.stun_invalid_stagger,
		Tuning.combat.stun_anim_duration,
		"missing now costs less than landing — flailing has become free tempo"
	)


func test_the_stagger_blocks_a_kill_as_well_as_a_stun() -> void:
	# **ONE TABLE, BOTH VERBS.** A stagger that only stopped stunning would let a
	# player flail at a stranger and immediately kill their own contract, which is
	# the tempo the punishment exists to take away.
	_a_stranger()
	_ctx.announced_contracts[PREY] = STRANGER
	_press(PREY)
	_advance()
	assert_true(_ctx.lockouts.is_staggered(PREY, _ctx.tick), "no stagger to test")
	assert_false(_kills.ready_for(PREY, _ctx), "a staggered player may still initiate a kill")


func test_the_attempt_cooldown_stops_a_second_press_landing_immediately() -> void:
	# `TUN-STUN-COOLDOWN`. The stagger and the cooldown are different rules: the
	# stagger blocks every initiation, the cooldown blocks this verb specifically,
	# and the cooldown is the longer of the two.
	_a_stranger()
	_press(PREY)
	_advance()
	var first := _refused.size()
	_release(PREY)
	_press(PREY)
	_advance()
	assert_eq(_refused.size(), first, "a second press inside the cooldown was judged")
	assert_gt(
		Tuning.combat.stun_cooldown,
		Tuning.combat.stun_invalid_stagger,
		"the cooldown no longer outlasts the stagger; one of the two rules is now inert"
	)


func test_holding_the_button_is_one_press() -> void:
	# Edge detection, for `KillSystem`'s reason: `PawnContext.held_buttons` is
	# rewritten at 60 Hz, so a system reading it would charge for a held finger
	# every tick of a walk across the district.
	_a_stranger()
	for _i: int in 6:
		_press(PREY)
		_advance()
	assert_eq(_refused.size(), 1, "%d whiffs from one held button" % _refused.size())
