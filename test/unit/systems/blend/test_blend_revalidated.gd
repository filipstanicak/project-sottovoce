## **A BLEND IS A CONDITION RE-VALIDATED EVERY TICK, NOT A STATE YOU KEEP.**
## US-0053, GDD-03 §4.1.1, TDD-07 §3.1.
##
## This is the story's critical test. A blend that silently keeps working after
## its conditions lapse is the **"I thought I was hidden"** bug class — the player
## is standing in what used to be a crowd, believing they are anonymous, and the
## game agrees with them. There is no error, no log line and no visible symptom
## until a hunter walks up.
##
## **THE POCKET IS TAKEN AWAY BY PEOPLE WHO ARE NOT THE HUNTER**, which is what
## makes it fair: a Startle scatters it, a procession walks out of it. So the
## check has to be against *this* tick's crowd, and "that tick" has to mean that
## tick rather than the next director pass.
extends GutTest

const PEER := 3

var _blend: BlendSystem
var _ctx: MatchContext
var _pawn: PawnContext
var _t: SuspicionTuning


func before_each() -> void:
	_t = Tuning.suspicion
	_blend = BlendSystem.new()
	_ctx = MatchContext.new()
	_ctx.crowd_hash.setup(AABB(Vector3(-20, -20, -20), Vector3(80, 40, 80)), 32)
	_pawn = PawnContext.new()
	_pawn.peer_id = PEER
	_pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	_pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[PEER] = _pawn
	_crowd(int(_t.blend_pocket_min_npc))


## Stand `count` NPCs a metre from the origin — comfortably inside
## `TUN-BLEND-POCKET-RADIUS`, indexed the way `CrowdDirector` indexes them at the
## top of the crowd stage.
func _crowd(count: int) -> void:
	var at := PackedVector3Array()
	for i: int in count:
		at.append(Vector3(cos(float(i)) * 1.0, 0.0, sin(float(i)) * 1.0))
	_ctx.crowd_hash.rebuild(at, [], at.size())


func _resolve(times: int) -> void:
	for _i: int in times:
		_ctx.tick += 1
		_blend.resolve(_ctx)


func _entry_window() -> int:
	return maxi(Tuning.ticks(&"TUN-BLEND-ENTRY-TIME"), 1)


## Enter a pocket and run out the entry window, so the crush is live.
func _held() -> void:
	assert_eq(_blend.request(PEER, _ctx), BlendKind.Kind.POCKET, "the pocket refused a legal entry")
	_resolve(_entry_window())
	assert_true(_blend.is_crushing(PEER), "the blend never reached HELD")


func test_the_windows_are_real_durations_and_not_single_ticks() -> void:
	# **WITHOUT THIS THE ENTRY ASSERTIONS BELOW PROVE NOTHING.** A window of one
	# tick makes "not yet crushing" unobservable, and every test here would pass on
	# an implementation with no entry phase at all.
	assert_gt(_entry_window(), 1, "TUN-BLEND-ENTRY-TIME is not a duration in ticks")
	assert_gt(maxi(Tuning.ticks(&"TUN-BLEND-EXIT-TIME"), 1), 1, "TUN-BLEND-EXIT-TIME is not either")


func test_four_npcs_admit_a_pocket_and_three_do_not() -> void:
	_crowd(int(_t.blend_pocket_min_npc) - 1)
	assert_eq(
		_blend.request(PEER, _ctx),
		BlendKind.Kind.NONE,
		"a pocket one NPC short of TUN-BLEND-POCKET-MIN-NPC was accepted"
	)
	_crowd(int(_t.blend_pocket_min_npc))
	assert_eq(_blend.request(PEER, _ctx), BlendKind.Kind.POCKET, "a legal pocket was refused")


func test_npcs_beyond_the_radius_do_not_count_toward_the_pocket() -> void:
	var at := PackedVector3Array()
	for i: int in int(_t.blend_pocket_min_npc):
		at.append(Vector3(_t.blend_pocket_radius + 1.0, 0.0, float(i)))
	_ctx.crowd_hash.rebuild(at, [], at.size())
	assert_eq(
		_blend.request(PEER, _ctx), BlendKind.Kind.NONE, "a crowd outside the radius made a pocket"
	)


func test_the_crush_does_not_start_until_the_entry_window_closes() -> void:
	# GDD-03 §4.1: entry is 0.35 s during which "you are vulnerable and visibly
	# transitioning". A crush that started on the press would pay a player for a
	# commitment they have not finished making.
	assert_eq(_blend.request(PEER, _ctx), BlendKind.Kind.POCKET)
	_resolve(_entry_window() - 1)
	assert_false(_blend.is_crushing(PEER), "the crush started inside the entry window")
	_resolve(1)
	assert_true(_blend.is_crushing(PEER), "the crush did not start when entry closed")


func test_a_pocket_dropping_below_four_breaks_the_blend_that_tick() -> void:
	# **THE STORY'S CRITICAL CRITERION.** Not on the next director pass, not when
	# the player next moves: the tick the fourth NPC leaves.
	_held()
	_crowd(int(_t.blend_pocket_min_npc) - 1)
	_resolve(1)
	assert_false(_blend.is_crushing(PEER), "a scattered pocket kept crushing")
	assert_eq(_blend.wire_kind(PEER), BlendKind.Kind.NONE, "the wire still reported a blend")


func test_a_pocket_that_holds_is_not_broken() -> void:
	# The counterfactual for the test above: an implementation that broke the blend
	# every tick would satisfy it perfectly.
	_held()
	_resolve(60)
	assert_true(_blend.is_crushing(PEER), "an intact pocket broke on its own")
	assert_eq(_blend.wire_kind(PEER), BlendKind.Kind.POCKET, "the wire lost an intact blend")


func test_exceeding_stroll_breaks_it() -> void:
	_held()
	_pawn.velocity = Vector3(_t.break_on_speed + 0.5, 0.0, 0.0)
	_resolve(1)
	assert_false(_blend.is_crushing(PEER), "walking out of a pocket kept the blend")


func test_a_floor_snap_does_not_break_it() -> void:
	# **HORIZONTAL, FOR THE REASON `SYS-SUSPICION` READS IT THAT WAY.** A grounded
	# `CharacterBody3D` carries a downward velocity from its floor snap, so a blend
	# measured in three axes would break on standing perfectly still — which is the
	# only thing a pocket blend asks the player to do.
	_held()
	_pawn.velocity = Vector3(0.0, -(_t.break_on_speed + 5.0), 0.0)
	_resolve(1)
	assert_true(_blend.is_crushing(PEER), "standing still broke a standing-still blend")


func test_damage_breaks_the_blend_rather_than_being_absorbed_by_it() -> void:
	# **BLEND PROTECTS ANONYMITY, NEVER THE BODY.** There is no method on
	# `BlendSystem` that refuses anything — the damage lands and the blend ends. A
	# blend that also protected the body would make patience free instead of merely
	# strongest, which is design law 4 read backwards.
	_held()
	_blend.report_damage(PEER, _ctx)
	assert_false(_blend.is_crushing(PEER), "a damaged player stayed blended")


func test_being_stunned_breaks_it() -> void:
	_held()
	_pawn.state_id = PawnStateId.STUNNED
	_resolve(1)
	assert_false(_blend.is_crushing(PEER), "a stunned player stayed blended")


func test_a_second_press_leaves_over_the_exit_window() -> void:
	_held()
	assert_eq(
		_blend.request(PEER, _ctx), BlendKind.Kind.NONE, "a press while blended entered again"
	)
	var exit_window := maxi(Tuning.ticks(&"TUN-BLEND-EXIT-TIME"), 1)
	_resolve(exit_window - 1)
	assert_eq(
		_blend.wire_kind(PEER), BlendKind.Kind.POCKET, "the blend ended inside the exit window"
	)
	assert_false(_blend.is_crushing(PEER), "the crush ran while standing up")
	_resolve(1)
	assert_eq(_blend.wire_kind(PEER), BlendKind.Kind.NONE, "the exit window never closed")


func test_the_crowd_walking_off_during_an_exit_is_not_a_break() -> void:
	# The player has already stood up. Re-validating a blend that is being *left*
	# would turn a clean exit into a break, and the two arm the score grace by
	# different routes — so the difference has to be real rather than incidental.
	_held()
	_blend.request(PEER, _ctx)
	_crowd(0)
	_resolve(1)
	assert_eq(
		_blend.wire_kind(PEER), BlendKind.Kind.POCKET, "an exit in progress was broken by the crowd"
	)


func test_the_wire_reports_nothing_for_a_player_who_never_blended() -> void:
	# **AN UNFILLED FIELD MUST DECODE AS "NOT BLENDED"** rather than as the first
	# real kind — `NONE` is zero for the reason `SlotTable` reserves slot 0.
	assert_eq(_blend.wire_kind(9999), BlendKind.Kind.NONE, "an unknown peer reported a blend")
	assert_eq(BlendKind.Kind.NONE, 0, "NONE is no longer the zero value")
	assert_true(BlendKind.fits_the_wire(), "the blend kinds no longer fit blend_state:u4")
