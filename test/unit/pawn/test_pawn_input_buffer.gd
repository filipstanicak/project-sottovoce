## The action buffer forgives an input pressed EARLY. GDD-02 §7.3, TDD-06 §3.
##
## `TUN-TRAVERSE-INPUT-BUFFER` 0.20 s early plus `TUN-TRAVERSE-MAGNET-WINDOW`
## 0.25 s late gives a player roughly 0.45 s around every traverse opportunity.
## That is enormous by action-game standards and it is correct: in this game the
## player's attention belongs on the *crowd*, not on their own footwork. A missed
## vault must be a decision error, never a timing error.
##
## The buffer is tested here, on `PawnContext`, and not through a state, because
## its whole reason for living in `step()` is that it must behave identically on
## the server and in a client replay — which is a property of the counter, not of
## whoever reads it.
extends GutTest

const DT := 1.0 / 60.0

var _ctx: PawnContext


func before_each() -> void:
	_ctx = PawnContext.new()


func _press_traverse() -> InputCommand:
	var input := InputCommand.empty(1)
	input.traverse = true
	return input


func test_a_press_arms_the_buffer_for_the_tuned_window() -> void:
	PawnInputBuffer.tick(_ctx, _press_traverse())
	assert_eq(
		_ctx.traverse_buffer_ticks,
		Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER"),
		"the buffer is not armed to the tunable"
	)


func test_the_window_is_the_tunable_at_the_step_rate() -> void:
	# 0.20 s at 60 Hz is 12 ticks. THE STEP RATE, not the net tick — the buffer is
	# decremented once per step(), so `Tuning.ticks()` (30 Hz) would give it 6 and
	# forgive 0.10 s while the document, the story and this file all say 0.20.
	var expected: int = int(
		round(Tuning.movement.traverse_input_buffer * Tuning.net.client_input_rate)
	)
	assert_eq(Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER"), expected)
	assert_eq(
		Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER"),
		2 * Tuning.ticks(&"TUN-TRAVERSE-INPUT-BUFFER"),
		"the two tick domains are no longer 2:1 — one of the rates moved"
	)


func test_a_traverse_pressed_early_survives_the_whole_window() -> void:
	PawnInputBuffer.tick(_ctx, _press_traverse())
	var window := Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER")
	for _i: int in window - 1:
		PawnInputBuffer.tick(_ctx, InputCommand.empty(1))
	assert_true(
		PawnInputBuffer.has_traverse(_ctx), "the traverse expired inside its own forgiveness window"
	)
	assert_true(PawnInputBuffer.consume_traverse(_ctx))


func test_it_expires_after_the_window_and_not_before() -> void:
	PawnInputBuffer.tick(_ctx, _press_traverse())
	for _i: int in Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER"):
		PawnInputBuffer.tick(_ctx, InputCommand.empty(1))
	assert_false(PawnInputBuffer.has_traverse(_ctx), "a stale traverse outlived its window")
	assert_false(PawnInputBuffer.consume_traverse(_ctx))


func test_consuming_spends_the_input_exactly_once() -> void:
	# A buffered input that stayed armed would re-fire on the next legal frame and
	# vault the player somewhere they never asked to go.
	PawnInputBuffer.tick(_ctx, _press_traverse())
	assert_true(PawnInputBuffer.consume_traverse(_ctx), "first consume failed")
	assert_false(PawnInputBuffer.consume_traverse(_ctx), "the same press fired twice")


func test_a_press_and_its_consumption_can_share_a_tick() -> void:
	# The machine ticks the buffer BEFORE the state runs, so pressing traverse
	# while already at the ledge resolves immediately rather than one tick late.
	PawnInputBuffer.tick(_ctx, _press_traverse())
	assert_true(PawnInputBuffer.consume_traverse(_ctx))


func test_the_ability_buffer_is_separate_from_the_traverse_one() -> void:
	# Two windows, two tunables, two reasons. Sharing a counter would let a
	# traverse eat an ability the player also pressed.
	var input := InputCommand.empty(1)
	input.ability_1 = true
	PawnInputBuffer.tick(_ctx, input)
	assert_true(PawnInputBuffer.has_ability(_ctx))
	assert_false(PawnInputBuffer.has_traverse(_ctx), "an ability armed the traverse buffer")
	assert_eq(_ctx.ability_buffer_ticks, Tuning.step_ticks(&"TUN-ABILITY-INPUT-BUFFER"))


func test_both_ability_slots_arm_the_same_window() -> void:
	var input := InputCommand.empty(1)
	input.ability_2 = true
	PawnInputBuffer.tick(_ctx, input)
	assert_true(PawnInputBuffer.has_ability(_ctx))


func test_a_respawn_clears_both_buffers() -> void:
	# A traverse buffered a tick before death must not fire out of the new spawn.
	PawnInputBuffer.tick(_ctx, _press_traverse())
	var input := InputCommand.empty(1)
	input.ability_1 = true
	PawnInputBuffer.tick(_ctx, input)

	_ctx.reset_for_spawn(Vector3.ZERO, 0.0)
	assert_false(PawnInputBuffer.has_traverse(_ctx), "a traverse survived a respawn")
	assert_false(PawnInputBuffer.has_ability(_ctx), "an ability survived a respawn")


func test_the_machine_ticks_the_buffer_inside_step() -> void:
	# THE POINT OF THE WHOLE FILE. A client-only buffer would predict a vault the
	# server never performed, and the correction would snap the pawn back through
	# the wall it just climbed. `step()` is the shared code path; nothing else is.
	var machine := PawnStateMachine.new()
	machine.register(IdleState.new())
	var ctx := PawnContext.new()
	ctx.state_id = PawnStateId.IDLE

	machine.step(ctx, _press_traverse(), DT)
	assert_true(PawnInputBuffer.has_traverse(ctx), "step() did not tick the action buffer")
	machine.free()
