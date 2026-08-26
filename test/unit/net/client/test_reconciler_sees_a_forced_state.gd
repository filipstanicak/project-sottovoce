## **THE SERVER CAN PUT A PAWN SOMEWHERE THE CLIENT COULD NOT HAVE PREDICTED, AND
## UNTIL US-0060 THE CLIENT NEVER FOUND OUT.** TDD-04 §4.2.
##
## `Reconciler` compared the server's answer against its own prediction with
## `error_against`, which is **position only** — deliberately, because
## `TUN-NET-RECONCILE-THRESHOLD` is expressed in metres and a velocity that differs
## while the position agrees corrects itself on the next tick anyway.
##
## That is true of velocity and false of state. Every state the server can force —
## `KillAnim` on a validated kill, `Dead` at a contact frame, `Stunned`,
## `Respawning` — happens to a pawn that may be standing perfectly still. The
## positional error is **0.000 m**, the reconciler returned early, and
## `own_state` rode the snapshot and was never applied.
##
## **NOTHING COULD SEE IT BEFORE NOW.** No test failed, nothing errored, and the
## symptom would have been a player pressing kill and watching their character
## keep walking. US-0060 is the first story that forces a state, which is why it is
## also the first that could tell.
extends GutTest


func _standing(state: StringName) -> PredictedState:
	var out := PredictedState.new()
	out.position = Vector3(12.0, 0.0, 36.0)
	out.velocity = Vector3.ZERO
	out.state_id = state
	out.grounded = true
	return out


func test_a_forced_state_is_invisible_to_the_distance() -> void:
	# **THE FINDING, AS ONE ASSERTION.** The two disagree about everything that
	# matters and agree to the millimetre.
	var predicted := _standing(PawnStateId.IDLE)
	var authoritative := _standing(PawnStateId.KILL_ANIM)
	assert_almost_eq(authoritative.error_against(predicted), 0.0, 0.0001)
	assert_lt(
		authoritative.error_against(predicted),
		Tuning.net.reconcile_threshold,
		"the fixture is not inside the threshold, so it cannot show the defect"
	)


func test_the_state_comparison_sees_it() -> void:
	assert_false(
		_standing(PawnStateId.KILL_ANIM).same_state_as(_standing(PawnStateId.IDLE)),
		"a forced KillAnim reads as agreement"
	)


func test_the_common_case_still_agrees() -> void:
	# Both peers run the same machine from the same commands, so they agree on
	# almost every tick of every match. A comparison that reported a divergence
	# here would replay sixty times a second and the integration suite's measured
	# zero replays would become sixty.
	for state: StringName in PawnStateId.ALL:
		assert_true(
			_standing(state).same_state_as(_standing(state)), "%s disagreed with itself" % state
		)


func test_every_state_the_server_can_force_is_one_a_client_cannot_reach_alone() -> void:
	# The four are worth naming: each is entered by a server decision the client has
	# no input for, so each is a case where the positional error is zero and the
	# state is everything.
	for state: StringName in [
		PawnStateId.KILL_ANIM, PawnStateId.DEAD, PawnStateId.STUNNED, PawnStateId.RESPAWNING
	]:
		assert_false(
			_standing(state).same_state_as(_standing(PawnStateId.IDLE)),
			"%s compared equal to Idle" % state
		)


func test_the_reconciler_asks_both_questions_before_returning_early() -> void:
	# **THE STRUCTURAL HALF.** The bug was one `and` short, in a branch that reads
	# perfectly. A behavioural test of this needs a driver, a body and a wire — the
	# integration harness has all three and is nine seconds from its budget — so the
	# guard is that the early return cannot be written without the state check.
	var early_return := ""
	for row: Array in SourceScanner.code_lines("res://scripts/net/client/reconciler.gd"):
		var line := String(row[1])
		if line.contains("reconcile_threshold") and line.contains("if "):
			early_return = line
			break
	assert_ne(early_return, "", "the reconciler no longer compares against the threshold at all")
	assert_true(
		early_return.contains("same_state_as"),
		(
			"The reconciler returns early on distance alone.\n"
			+ "A server-forced state arrives at a pawn that may be standing still, so the\n"
			+ "positional error is 0.000 m and `own_state` is never applied.\n"
			+ early_return.strip_edges()
		)
	)


func test_a_forced_replay_is_counted_apart_from_a_late_one() -> void:
	# `Reconciler.forced` exists so the two can be told apart in the readout: a
	# replay inside the threshold is the server having *decided* something, and a
	# replay outside it is latency. A single counter would report a healthy
	# connection as a sick one every time somebody was killed.
	var source := SourceScanner.read("res://scripts/net/client/reconciler.gd")
	assert_true(source.contains("forced += 1"), "forced replays are not counted")
