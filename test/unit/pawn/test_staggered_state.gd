## **THE FIFTEENTH STATE.** ADR-0017, GDD-02 §3.1.
##
## `Stunned` is done to you by another player; `Staggered` is done to you by your
## own failed action. Everything below is one of those two halves.
##
## **THE PROPERTY THAT MATTERS MOST IS NOT THE DURATION.** A test that a stagger
## ends after 1.5 s passes just as happily against an initiation lockout, which is
## what this state replaced. What separates them is that a staggered player
## **cannot move and can be reached** — so the assertions worth their space are
## that input cannot leave the state, and that a stun can enter it.
extends GutTest

var _machine: PawnStateMachine
var _ctx: PawnContext


func before_each() -> void:
	_machine = PawnStateMachine.new()
	add_child_autofree(_machine)
	_ctx = PawnContext.new()
	_ctx.peer_id = 7
	_ctx.reset_for_spawn(Vector3.ZERO, 0.0)
	_machine.spawn_into(_ctx, PawnStateId.IDLE)


func _stagger(seconds_id: StringName) -> void:
	_ctx.arm_stagger(Tuning.step_ticks(seconds_id))
	_machine.transition(_ctx, PawnStateId.STAGGERED, PawnState.PRIORITY_COMBAT)
	_ctx.state_timer_ticks = 0


func _step(times: int) -> void:
	for _i: int in times:
		_machine.step(_ctx, InputCommand.new(), 1.0 / 60.0)


# --- the premise ----------------------------------------------------------


func test_the_state_is_registered_at_all() -> void:
	# Guards the guard. Every assertion below is satisfied by a machine that
	# refuses to enter the state, because a refused transition leaves the pawn in
	# `Idle` and `Idle` also declines to be a stagger.
	assert_true(_machine.has_state(PawnStateId.STAGGERED), "Staggered was never registered")
	_stagger(&"TUN-KILL-CONTEST-STAGGER")
	assert_eq(_ctx.state_id, PawnStateId.STAGGERED, "the pawn did not enter Staggered")


# --- the duration ---------------------------------------------------------


func test_it_lasts_exactly_as_long_as_the_rule_that_caused_it() -> void:
	_stagger(&"TUN-KILL-CONTEST-STAGGER")
	var window := Tuning.step_ticks(&"TUN-KILL-CONTEST-STAGGER")
	_step(window - 1)
	assert_eq(_ctx.state_id, PawnStateId.STAGGERED, "the stagger ended early")
	_step(1)
	assert_eq(_ctx.state_id, PawnStateId.IDLE, "the stagger never ended")


## **THREE CAUSES, THREE DURATIONS, ONE STATE.** A single-duration state would
## pass the test above and be wrong for two of the three rules that enter it.
func test_a_flail_costs_longer_than_a_lost_contest() -> void:
	var flail := Tuning.step_ticks(&"TUN-STUN-INVALID-STAGGER")
	var contest := Tuning.step_ticks(&"TUN-KILL-CONTEST-STAGGER")
	assert_gt(flail, contest, "the two staggers stopped differing, so this file proves less")
	_stagger(&"TUN-STUN-INVALID-STAGGER")
	_step(contest)
	assert_eq(_ctx.state_id, PawnStateId.STAGGERED, "a flail ended on the contest's clock")


## **TRAP 9, AT THE ONE SEAM WHERE THE DOMAINS MEET.** Both combat systems hold
## every other deadline in **net** ticks and this counter advances in **step**
## ticks; the two are both plausible integers, so getting it wrong halves the
## punishment silently. `arm_stagger`'s argument name says which it wants, and
## this is what would go red if a caller reached for `Tuning.ticks()` instead.
func test_the_window_is_step_ticks_and_not_net_ticks() -> void:
	var step_domain := Tuning.step_ticks(&"TUN-STUN-INVALID-STAGGER")
	var net_domain := Tuning.ticks(&"TUN-STUN-INVALID-STAGGER")
	assert_gt(step_domain, net_domain, "the two tick domains stopped differing")
	_stagger(&"TUN-STUN-INVALID-STAGGER")
	_step(net_domain)
	assert_eq(_ctx.state_id, PawnStateId.STAGGERED, "the stagger ran on the 30 Hz clock")


## **AN UNARMED STAGGER RUNS LONG RATHER THAN NOT AT ALL.** A client is forced
## into this state by a snapshot and is never told the total, only the elapsed —
## so the fallback must be a ceiling. Ending immediately is a punishment that
## silently does not happen; ending late is one the server's next snapshot cuts
## short. UI_UX_SPEC §3.3's rule applied to a state: never newer, older is fine.
func test_an_unarmed_stagger_falls_back_to_the_ceiling() -> void:
	_ctx.stagger_ticks = 0
	_machine.transition(_ctx, PawnStateId.STAGGERED, PawnState.PRIORITY_COMBAT)
	_ctx.state_timer_ticks = 0
	_step(1)
	assert_eq(_ctx.state_id, PawnStateId.STAGGERED, "an unarmed stagger ended on its first step")
	_step(StaggeredState.ceiling_ticks())
	assert_eq(_ctx.state_id, PawnStateId.IDLE, "the ceiling never expired")


## The ceiling is `max` of the three real staggers rather than a fourth number
## that could be set to a value the first three contradict.
func test_the_ceiling_covers_every_rule_that_can_enter_the_state() -> void:
	var ceiling := StaggeredState.ceiling_ticks()
	for id: StringName in [
		&"TUN-KILL-CONTEST-STAGGER", &"TUN-STUN-INVALID-STAGGER", &"TUN-LUNGE-WHIFF-STAGGER"
	]:
		assert_true(
			ceiling >= Tuning.step_ticks(id),
			"a client forced into a stagger would end %s early" % id
		)


func test_arming_clamps_to_at_least_one_tick() -> void:
	_ctx.arm_stagger(0)
	assert_eq(_ctx.stagger_ticks, 1, "a rounded-down tunable produced a stagger of no length")


# --- what a staggered player can and cannot do ----------------------------


## **THE ASSERTION THAT SEPARATES A STATE FROM A LOCKOUT.** An initiation lockout
## blocks presses and leaves the player free to sprint out of the space they just
## announced themselves in, which is why "flailing is strictly worse than doing
## nothing" was false before this state existed.
func test_input_cannot_leave_the_state() -> void:
	_stagger(&"TUN-STUN-INVALID-STAGGER")
	var running := InputCommand.new()
	running.move = Vector2(0.0, 1.0)
	running.buttons = InputBits.RUN | InputBits.SPRINT | InputBits.TRAVERSE | InputBits.BLEND
	for _i: int in 20:
		_machine.step(_ctx, running, 1.0 / 60.0)
	assert_eq(_ctx.state_id, PawnStateId.STAGGERED, "a staggered player ran out of it")


## **NEVER-DO #13, AND THIS IS THE PROPERTY THAT ENFORCES IT.** A whiffed lunger
## would otherwise be in a locomotion state, which is stunnable — so a stagger
## stun could not reach would be a weakening dressed as an addition. It is also
## GDD-04 §3.4's named counterplay to Lunge, paid off.
func test_a_staggered_player_can_still_be_stunned() -> void:
	_stagger(&"TUN-LUNGE-WHIFF-STAGGER")
	var landed := _machine.transition(_ctx, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT)
	assert_true(landed, "a stun could not reach a staggered player")
	assert_eq(_ctx.state_id, PawnStateId.STUNNED)


func test_a_staggered_player_can_still_be_killed() -> void:
	_stagger(&"TUN-KILL-CONTEST-STAGGER")
	assert_true(
		_machine.transition(_ctx, PawnStateId.DEAD, PawnState.PRIORITY_FATAL),
		"a stagger that could not be killed out of would be a safe place to fail"
	)


## **`Stunned` MUST REMAIN THE ONLY STATE THAT TAKES THE CAMERA.** That is the
## stun's signature — four seconds of not even choosing where to look — and
## nothing else may borrow it. A staggered player watches their prey leave and
## can look at them, which is a materially smaller punishment and reads as one.
func test_it_keeps_the_camera_where_a_stun_takes_it() -> void:
	_stagger(&"TUN-KILL-CONTEST-STAGGER")
	assert_true(_machine.camera_controlled(_ctx), "a stagger took the camera")
	_machine.transition(_ctx, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT)
	assert_false(_machine.camera_controlled(_ctx), "the stun stopped taking the camera")


func test_it_does_not_drive_its_own_position() -> void:
	# It stops the pawn rather than moving it, the way `KillAnim` does — so the
	# driver integrates normally and friction brings a running player to rest.
	_stagger(&"TUN-KILL-CONTEST-STAGGER")
	assert_false(_machine.drives_position(_ctx), "a stagger claimed to write its own position")


func test_a_respawn_clears_a_stagger() -> void:
	_ctx.arm_stagger(600)
	_ctx.reset_for_spawn(Vector3.ZERO, 0.0)
	assert_eq(_ctx.stagger_ticks, 0, "a respawned player inherited their own punishment")
