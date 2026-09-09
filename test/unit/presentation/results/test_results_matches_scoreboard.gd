## US-0077: 100 seeded logs, totals and displayed contributions share the real fold.
extends GutTest

const FIXTURE = preload("res://test/unit/presentation/results/results_fixture.gd")


func test_results_matches_scoreboard_for_100_logs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 770077
	for _run: int in 100:
		var events := _log(rng)
		var vm := ResultsVm.new()
		vm.present(events, FIXTURE.roster(), 2)
		var totals := ScoreFold.fold(events)
		for player: Dictionary in vm.players:
			var actor := int(player["id"])
			assert_eq(player["total"], int(totals.get(actor, 0)))
			var contributions := 0
			for row: Dictionary in vm.breakdown(actor):
				contributions += int(row["points"])
			assert_eq(contributions, int(totals.get(actor, 0)))


func test_zero_event_players_are_not_lost() -> void:
	var vm := ResultsVm.new()
	vm.present([], FIXTURE.roster(), 5)
	assert_eq(vm.players.size(), 6)
	assert_eq(vm.selected, 5)
	for player: Dictionary in vm.players:
		assert_eq(player["total"], 0)
	assert_eq(vm.best_actor, 0)


func _log(rng: RandomNumberGenerator) -> Array[ScoreEvent]:
	var events: Array[ScoreEvent] = []
	for i: int in rng.randi_range(0, 160):
		var kind := ScoreKinds.ALL[rng.randi_range(0, ScoreKinds.ALL.size() - 1)]
		var worth := float(rng.randi_range(-100, 600))
		if kind == Ids.SCORE_DEATH:
			worth = 0.0
		var award := ScoreAward.new(
			rng.randi_range(0, 15000), kind, rng.randi_range(1, 6), 0, worth
		)
		events.append(ScoreEvent.new(i + 1, award, Tuning.match_rules, i + 1))
	return events
