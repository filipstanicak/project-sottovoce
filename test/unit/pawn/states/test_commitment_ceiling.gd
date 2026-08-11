## **NO UNSKIPPABLE COMMITMENT EXCEEDS 1.4 s.** GDD-02 §5, US-0024 criterion 3.
##
## `TUN-FEEL-MAX-COMMIT` is the longest the game may take a player's control away
## for something they chose to do. Only `KillAnim` may sit exactly at it: the
## kill is the price of the kill, and the killer standing fully visible for 1.4 s
## is the reason a kill in the open is a bad idea even when it works.
##
## **THE WORD THAT MATTERS IS UNSKIPPABLE.** Duration alone is the wrong test,
## and `Climb` is why: a 9 m façade at `TUN-SPEED-CLIMB` takes 3.2 s, more than
## twice the ceiling, and does not breach it — because pulling away from the wall
## lets go on any tick. A commitment you can back out of is not a commitment. So
## every state below is classified by whether the player can end it, not by how
## long it runs, and the ceiling is applied only to what has no way out.
extends GutTest

const DT := 1.0 / 60.0

var _machine: PawnStateMachine


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())


func after_each() -> void:
	_machine.free()


# -------------------------------------------------------------- the ceiling --


func test_the_kill_sits_exactly_at_the_ceiling() -> void:
	# Invariant 15 asserts <=; §5 says the kill is the only thing allowed AT it,
	# which is a stronger claim and the one that carries the design.
	assert_almost_eq(Tuning.combat.kill_anim_duration, Tuning.movement.max_commit, 0.001)
	assert_almost_eq(Tuning.movement.max_commit, 1.4, 0.001)


func test_every_other_committed_animation_is_strictly_under_it() -> void:
	# Named individually rather than swept, because the interesting part is which
	# durations count as committed animations at all.
	var animations := {
		"vault": Tuning.movement.vault_duration,
		"mantle": Tuning.movement.mantle_duration,
		"stun anim": Tuning.combat.stun_anim_duration,
		"drop stagger": Tuning.movement.drop_stagger,
	}
	for name: String in animations:
		assert_lt(
			float(animations[name]),
			Tuning.movement.max_commit,
			(
				"%s is %.2f s, at or over the %.2f s ceiling"
				% [name, animations[name], Tuning.movement.max_commit]
			)
		)


func test_defence_commits_for_half_as_long_as_offence() -> void:
	# The stun animation is deliberately half the kill's. Design law 5: the prey
	# must have teeth, and a defensive action that cost the same commitment as an
	# offensive one would blunt them.
	assert_almost_eq(Tuning.combat.stun_anim_duration / Tuning.combat.kill_anim_duration, 0.5, 0.05)


# ------------------------------------------------- who can get out, and how --


func test_a_climb_is_long_and_abandonable() -> void:
	# 3.2 s at the tuned maximum height — over twice the ceiling, and legitimate,
	# because the player lets go by pulling away from the wall. If this ever stops
	# being abandonable, the duration becomes a breach on the same day.
	var seconds := Tuning.movement.traverse_climb_max_height / Tuning.movement.climb
	assert_gt(seconds, Tuning.movement.max_commit, "the climb no longer needs its exit")

	var ctx := PawnContext.new()
	ctx.state_id = PawnStateId.CLIMB
	ctx.yaw = 0.0
	ctx.traverse_start = Vector3.ZERO
	ctx.traverse_target = Vector3(0.0, Tuning.movement.traverse_climb_max_height, 0.0)
	var pulling_away := InputCommand.empty(1)
	pulling_away.move = Vector2(0.0, -1.0)
	ctx.state_timer_ticks += 1
	assert_eq(
		_machine.state_for(PawnStateId.CLIMB).step(ctx, pulling_away, DT),
		PawnStateId.DROP,
		"a climb longer than the commitment ceiling cannot be abandoned"
	)


func test_a_vault_is_short_because_it_cannot_be_abandoned() -> void:
	# The other half of the same rule. Vault has no player exit, so its duration
	# is what protects the player — and it is well under.
	var vault := _machine.state_for(PawnStateId.VAULT)
	assert_false(vault.is_interruptible(PawnContext.new()), "the vault became interruptible")
	assert_lt(Tuning.movement.vault_duration, Tuning.movement.max_commit)
	assert_lt(Tuning.movement.mantle_duration, Tuning.movement.max_commit)


func test_being_stunned_is_exempt_and_must_stay_that_way() -> void:
	# `TUN-STUN-FREEZE` is four seconds — nearly three times the ceiling — and the
	# ceiling does not apply, because §5 governs what a player COMMITS TO, not
	# what is done to them. Four seconds of helplessness is the tooth in design
	# law 5, and CLAUDE.md never-do #13 forbids filing it down.
	assert_gt(Tuning.combat.stun_freeze, Tuning.movement.max_commit)
	var stunned := _machine.state_for(PawnStateId.STUNNED)
	assert_false(stunned.is_interruptible(PawnContext.new()), "a stun became escapable")


func test_a_hard_landing_is_the_longest_thing_you_can_do_to_yourself() -> void:
	# **RECORDED, NOT SILENTLY EXEMPTED.** A roof-to-street drop is 8.5 m of fall
	# plus TUN-TRAVERSE-DROP-STAGGER, and nothing below FATAL interrupts either
	# part. It is not an *animation*, so criterion 3 is met — but it is the longest
	# no-input window a player can walk into by choice, and the number belongs
	# somewhere a reader will find it rather than in a comment.
	var fall_ticks := TraversalResolver.fall_ticks(VetraioLayout.ROOF_Y - VetraioLayout.STREET_Y)
	var total := FeelChain.ms_for_ticks(fall_ticks) / 1000.0 + Tuning.movement.drop_stagger
	assert_gt(total, Tuning.movement.max_commit, "the roof drop got cheaper without a note here")
	assert_lt(
		total,
		Tuning.combat.stun_freeze,
		"a self-inflicted lockout now outlasts being stunned by another player"
	)
	gut.p(
		(
			"roof-to-street drop: %.2f s of fall + stagger, no input, vs a %.2f s ceiling"
			% [total, Tuning.movement.max_commit]
		)
	)
