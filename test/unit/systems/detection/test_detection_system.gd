## **THE ANONYMITY RULE, DRIVEN THROUGH THE REAL PASS.** US-0055, TDD-07 §4.
##
## `RenderState.of()` is pure and exhaustively tested beside it. What this file
## tests is everything around it: that the pass reaches every ordered pair, that
## the early-out ladder removes the ones it claims to, that the answer comes from
## the **announced** contract rather than the graph's, and that a departed peer
## leaves no tint behind.
extends GutTest

const HUNTER := 11
const PREY := 12
const STRANGER := 13

## **A FOURTH PLAYER, AND A THREE-PLAYER RING IS WHY.** In a cycle of three
## everybody is somebody's hunter and somebody's prey, so there is no such thing
## as a stranger — the first version of this file asserted that `STRANGER` saw an
## Exposed `PREY` as `PLAIN` and read `HARD`, which is the rule working: `PREY`
## was their pursuer. Four is the smallest lobby in which "everyone else" exists.
const BYSTANDER := 14

var _system: DetectionSystem
var _ctx: MatchContext


func before_each() -> void:
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_system.setup(_ctx)
	for peer: int in [HUNTER, PREY, STRANGER, BYSTANDER]:
		_spawn(peer)


func _spawn(peer: int) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(Vector3(float(peer), 0.0, 0.0), 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn
	return pawn


func _tell(peer: int, contract: int) -> void:
	_ctx.announced_contracts[peer] = contract


func _tier(peer: int, tier: int) -> void:
	(_ctx.pawn_contexts[peer] as PawnContext).tier = tier


## **NOT `_pass()`.** GUT's own base class declares `_pass(Variant)`, so a helper
## by that name is a signature clash — the file fails to parse, GUT skips it, and
## the suite reports green while running one script fewer. Caught by
## `.ci/run_gut.sh`'s script count and by nothing else.
func _resolve() -> void:
	_ctx.tick += 1
	_system.tick(_ctx, MatchContext.net_dt())


func _seen(observer: int, subject: int) -> int:
	return _ctx.render_states.state_of(observer, subject)


func test_the_stage_is_after_suspicion() -> void:
	# **THE ORDERING THIS SYSTEM'S CORRECTNESS RESTS ON.** Detection renders from
	# tier; a tick of lag makes the silhouette disagree with the tier indicator.
	assert_eq(_system.stage(), &"detection", "SYS-DETECTION does not occupy the detection stage")
	assert_gt(
		SystemOrder.position_of(&"detection"),
		SystemOrder.position_of(&"suspicion"),
		"detection runs before suspicion resolves"
	)


func test_the_story_case_one_exposed_player_seen_by_three() -> void:
	# HUNTER holds PREY; PREY holds STRANGER. PREY goes Exposed.
	_tell(HUNTER, PREY)
	_tell(PREY, STRANGER)
	_tell(STRANGER, BYSTANDER)
	_tell(BYSTANDER, HUNTER)
	_tier(PREY, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_eq(_seen(HUNTER, PREY), RenderState.State.HARD, "the hunter was shown nothing")
	assert_eq(_seen(STRANGER, PREY), RenderState.State.HARD, "PREY's own prey was not warned")
	assert_eq(_seen(BYSTANDER, PREY), RenderState.State.PLAIN, "a bystander saw an Exposed player")
	# And the reverse pair: PREY's own prey is Anonymous, so nothing there either.
	assert_eq(_seen(PREY, STRANGER), RenderState.State.PLAIN, "an Anonymous subject was rendered")


func test_an_exposed_pursuer_is_hard_to_their_own_prey() -> void:
	_tell(HUNTER, PREY)
	_tier(HUNTER, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_eq(_seen(PREY, HUNTER), RenderState.State.HARD, "a reckless pursuer was not shown")
	assert_eq(_seen(BYSTANDER, HUNTER), RenderState.State.PLAIN, "a bystander saw the pursuer")


func test_nothing_is_rendered_while_everyone_is_anonymous() -> void:
	_tell(HUNTER, PREY)
	_tell(PREY, STRANGER)
	_resolve()
	assert_eq(_ctx.render_states.marked_pairs(), 0, "an Anonymous district rendered something")
	# **THE LADDER'S FIRST RUNG DID THE WORK**, which is the claim TDD-07 §4.3 makes:
	# about seventy per cent of pairs leave on the tier check alone.
	assert_eq(_system.pairs_considered, 0, "the tier early-out let a pair through")


func test_the_matrix_costs_no_raycasts() -> void:
	# **NOT AN OPTIMISATION — THE DESIGN.** An Exposed outline is drawn *through*
	# geometry (GDD-03 §2.3), so occlusion must not gate it. The raycasts TDD-07
	# §4.3 budgets belong to the Compass lock and SCORE-FOCUS, which are later.
	_tell(HUNTER, PREY)
	_tier(PREY, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_gt(_ctx.render_states.marked_pairs(), 0, "nothing was rendered — this proves nothing")
	assert_eq(_system.raycasts_last_tick, 0, "the render-state pass spent a raycast")


func test_the_announced_contract_decides_and_not_the_graph() -> void:
	# **`SYS-CONTRACT` REPAIRS THE CYCLE IN THE TICK A DEATH RESOLVES AND HOLDS THE
	# ANNOUNCEMENT FOR `TUN-CONTRACT-REASSIGN-DELAY`.** Rendering from the graph
	# would put a tint on a player the hunter has not been given yet — the
	# silhouette arriving before the Compass, and the breath worth nothing.
	_tier(PREY, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_eq(_seen(HUNTER, PREY), RenderState.State.PLAIN, "an untold hunter saw their contract")
	_tell(HUNTER, PREY)
	_resolve()
	assert_eq(_seen(HUNTER, PREY), RenderState.State.HARD, "a told hunter saw nothing")


func test_the_matrix_is_rebuilt_rather_than_accumulated() -> void:
	# A stale entry is a tint drawn from a relationship that has ended, and it would
	# persist for the rest of the match.
	_tell(HUNTER, PREY)
	_tier(PREY, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_eq(_seen(HUNTER, PREY), RenderState.State.HARD, "the premise failed")
	_tier(PREY, SuspicionMath.Tier.ANONYMOUS)
	_resolve()
	assert_eq(
		_seen(HUNTER, PREY), RenderState.State.PLAIN, "a tint outlived the tier that caused it"
	)


func test_a_departed_peer_leaves_no_tint() -> void:
	_tell(HUNTER, PREY)
	_tier(PREY, SuspicionMath.Tier.EXPOSED)
	_resolve()
	_ctx.pawn_contexts.erase(PREY)
	_resolve()
	assert_eq(_seen(HUNTER, PREY), RenderState.State.PLAIN, "a departed player was still rendered")


func test_a_subject_is_never_rendered_to_themselves() -> void:
	# A client that received itself as a remote pawn would draw a second copy of
	# itself; one that received itself *tinted* would be told its own tier through a
	# channel that is meant to carry somebody else's.
	_tell(HUNTER, HUNTER)
	_tier(HUNTER, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_eq(_seen(HUNTER, HUNTER), RenderState.State.PLAIN, "a player was rendered to themselves")
