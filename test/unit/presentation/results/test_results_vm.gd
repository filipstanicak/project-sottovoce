extends GutTest

const FIXTURE = preload("res://test/unit/presentation/results/results_fixture.gd")


func test_deaths_are_local_killer_counts_not_bonus_rows() -> void:
	var vm := ResultsVm.new()
	(
		vm
		. present(
			[
				FIXTURE.event(1, 1, Ids.SCORE_DEATH, 0),
				FIXTURE.event(2, 1, Ids.SCORE_DEATH, 0),
				FIXTURE.event(3, 3, Ids.SCORE_DEATH, 0),
				FIXTURE.event(4, 1, Ids.SCORE_SILENT, 200),
				FIXTURE.event(5, 1, Ids.SCORE_SILENT, 400),
			],
			FIXTURE.roster(),
			1
		)
	)
	assert_eq(vm.killers(), [{"id": 2, "count": 2}])
	assert_eq(vm.breakdown(1), [{"kind": Ids.SCORE_SILENT, "count": 2, "points": 600}])
	vm.select(3)
	assert_eq(vm.killers(), [{"id": 2, "count": 2}])


func test_best_kill_is_a_contract_group_not_the_largest_single_award() -> void:
	var vm := ResultsVm.new()
	(
		vm
		. present(
			[
				FIXTURE.event(1, 1, Ids.SCORE_CONTRACT, 100, 1),
				FIXTURE.event(2, 1, Ids.SCORE_SILENT, 200, 1),
				FIXTURE.event(3, 1, Ids.SCORE_DEATH, 0, 1),
				FIXTURE.event(4, 3, Ids.SCORE_STUN, 2000, 2),
				FIXTURE.event(5, 2, Ids.SCORE_CONTRACT, 100, 3),
				FIXTURE.event(6, 2, Ids.SCORE_PATIENT, 250, 3),
			],
			FIXTURE.roster(),
			1
		)
	)
	assert_eq(vm.best_actor, 2)
	assert_eq(vm.best_points, 350)
	assert_eq(vm.best_stack.size(), 2)


func test_roster_is_copied_and_placement_uses_the_shared_rule() -> void:
	var roster := FIXTURE.roster()
	var vm := ResultsVm.new()
	vm.present([FIXTURE.event(1, 6, Ids.SCORE_STUN, 900)], roster, 6)
	roster[0]["name"] = "Changed after delivery"
	assert_eq(vm.players[0]["id"], 6)
	assert_eq(vm.player_for(1)["name"], "Player 1")
	assert_eq(vm.player_for(1)["placement"], 2)
	assert_false(roster[0].has("total"))
	vm.select(99)
	assert_eq(vm.selected, 6)


func test_votes_and_expired_time_never_close_the_screen() -> void:
	var vm := ResultsVm.new()
	vm.present([], FIXTURE.roster(), 1)
	assert_false(vm.request_skip())
	vm.phase_changed(MatchPhase.Phase.RESULTS)
	assert_false(vm.request_skip())
	vm.skip_state(0, 6, false, 25, true)
	assert_true(vm.request_skip())
	assert_false(vm.request_skip())
	vm.skip_state(6, 6, true, 0, true)
	assert_true(vm.active)
	vm.phase_changed(MatchPhase.Phase.LOBBY)
	assert_false(vm.active)
	assert_false(vm.available)
	assert_true(vm.players.is_empty())
	assert_false(vm.requested)


func test_payload_before_phase_and_phase_before_payload_are_both_valid() -> void:
	for payload_first: bool in [false, true]:
		var vm := ResultsVm.new()
		if payload_first:
			vm.present([], FIXTURE.roster(), 1)
			assert_false(vm.active)
		vm.phase_changed(MatchPhase.Phase.RESULTS)
		if not payload_first:
			assert_false(vm.available)
			vm.present([], FIXTURE.roster(), 1)
		assert_true(vm.active)
		assert_true(vm.available)


func test_shared_winners_keep_the_shared_rule_and_distinct_treatment() -> void:
	var vm := ResultsVm.new()
	var events: Array[ScoreEvent] = [
		FIXTURE.event(1, 1, Ids.SCORE_STUN, 300),
		FIXTURE.event(2, 2, Ids.SCORE_STUN, 300),
	]
	vm.present(events, FIXTURE.roster(), 2)
	assert_true(vm.shared_win)
	assert_eq(vm.players[0]["placement"], 1)
	assert_eq(vm.players[1]["placement"], 1)
	assert_eq(vm.players[2]["placement"], 3)
	assert_eq(vm.players[5]["total"], 0)
	vm.present([], FIXTURE.roster(), 2)
	assert_true(vm.shared_win, "a scoreless match is also explicitly shared")


func test_only_authoritative_results_time_finishes_the_surface() -> void:
	var vm := ResultsVm.new()
	vm.present([], FIXTURE.roster(), 1)
	vm.results_time(0, 30.0)
	assert_false(vm.finished, "lobby zero is not results expiry")
	vm.phase_changed(MatchPhase.Phase.RESULTS)
	vm.results_time(31, 30.0)
	assert_eq(vm.seconds_left, 2)
	assert_false(vm.finished)
	vm.results_time(0, 30.0)
	assert_true(vm.finished)
	assert_true(vm.active, "expiry does not invent a lobby transition")
	vm.phase_changed(MatchPhase.Phase.LOBBY)
	assert_false(vm.finished)
