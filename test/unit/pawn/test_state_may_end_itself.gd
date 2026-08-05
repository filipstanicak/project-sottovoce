## **AN UNINTERRUPTIBLE STATE CAN STILL END.**
##
## Interruption is something done TO a state by something else. A state returning
## a new id from `step()` is not that — it is completion, and gating it on
## `is_interruptible()` makes every uninterruptible state permanent.
##
## `Vault` and `KillAnim` were both built to refuse NORMAL interrupts, and until
## US-0019 neither could ever end: `step()` requested the exit at the state's own
## priority, the machine compared `priority <= interrupt_priority` and refused.
## `KillAnim` has been that way since US-0013 and nothing noticed, because
## nothing had ever run it.
##
## The symptom would not be an error. It would be a player permanently frozen
## mid-vault, or a kill animation that never returned control — in a game where
## the only escape is dying.
extends GutTest

const DT := 1.0 / 60.0

var _machine: PawnStateMachine
var _ctx: PawnContext


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())
	_ctx = PawnContext.new()


func after_each() -> void:
	_machine.free()


func _plan_vault() -> void:
	_ctx.state_id = PawnStateId.VAULT
	_ctx.traverse_case = TraversalResolver.Case.VAULT
	_ctx.traverse_start = Vector3.ZERO
	_ctx.traverse_target = Vector3(0.0, 0.0, 1.4)
	_ctx.traverse_peak_y = 1.1


func test_a_vault_ends_on_its_own() -> void:
	_plan_vault()
	var ticks := TraversalResolver.duration_ticks(TraversalResolver.Case.VAULT)
	for _i: int in ticks + 4:
		_machine.step(_ctx, InputCommand.empty(1), DT)
		if _ctx.state_id != PawnStateId.VAULT:
			break
	assert_eq(_ctx.state_id, PawnStateId.IDLE, "the pawn is frozen in the vault forever")


func test_a_kill_animation_ends_on_its_own() -> void:
	# The same shape, and the one where being stuck is worst: `KillAnim` refuses
	# interruption after the contact frame precisely so a landed kill cannot be
	# un-killed, which also meant it could never hand control back.
	_ctx.state_id = PawnStateId.KILL_ANIM
	for _i: int in Tuning.step_ticks(&"TUN-KILL-ANIM-DURATION") + 4:
		_machine.step(_ctx, InputCommand.empty(1), DT)
		if _ctx.state_id != PawnStateId.KILL_ANIM:
			break
	assert_eq(_ctx.state_id, PawnStateId.IDLE, "the killer is frozen in the animation forever")


func test_being_stunned_still_ends_on_its_own() -> void:
	_ctx.state_id = PawnStateId.STUNNED
	for _i: int in Tuning.step_ticks(&"TUN-STUN-FREEZE") + 4:
		_machine.step(_ctx, InputCommand.empty(1), DT)
		if _ctx.state_id != PawnStateId.STUNNED:
			break
	assert_ne(_ctx.state_id, PawnStateId.STUNNED, "a stun never wears off")


func test_an_outside_transition_is_still_refused() -> void:
	# The fix must not open the gate it was protecting. Nothing at NORMAL may take
	# a pawn out of a vault, which is what stops a player changing their mind
	# about a wall halfway over it.
	_plan_vault()
	assert_false(
		_machine.transition(_ctx, PawnStateId.IDLE, PawnState.PRIORITY_NORMAL),
		"a NORMAL interrupt was admitted after all"
	)
	assert_eq(_ctx.state_id, PawnStateId.VAULT)


func test_combat_may_still_interrupt() -> void:
	_plan_vault()
	assert_true(
		_machine.transition(_ctx, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT),
		"a stun could not interrupt a vault"
	)


func test_an_interruptible_state_is_unaffected() -> void:
	# Every locomotion state says yes to everything. The distinction only bites
	# where a state declines.
	_ctx.state_id = PawnStateId.STROLL
	assert_true(_machine.transition(_ctx, PawnStateId.IDLE, PawnState.PRIORITY_NORMAL))
