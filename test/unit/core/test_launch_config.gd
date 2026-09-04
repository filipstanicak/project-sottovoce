## The command line contract. TDD-12 §4.
##
## Parsed in pure Core, so this suite needs no engine, no scene and no server —
## which is the only reason the awkward cases below get tested at all.
extends GutTest

## `TUN-CROWD-COUNT-MAX`. Passed in rather than read, because Core may not touch
## an autoload — the same reason `parse` takes `default_max_players`.
const MAX_CROWD := 90

const MIN_PLAYERS := 4
const MAX_PLAYERS := 6


func _parse(args: Array) -> LaunchConfig:
	return LaunchConfig.parse(PackedStringArray(args), MAX_PLAYERS)


func test_an_empty_command_line_is_a_menu_client() -> void:
	var c := _parse([])
	assert_false(c.is_server, "no --server means client")
	assert_false(c.should_autoconnect(), "no --connect means the menu")
	assert_eq(c.port, LaunchConfig.DEFAULT_PORT)
	assert_eq(c.max_players, MAX_PLAYERS, "max_players defaults to TUN-LOBBY-MAX-PLAYERS")
	assert_eq(
		c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0, "a bare launch must be valid"
	)


func test_the_server_line_parses() -> void:
	var c := _parse(["--server", "--port", "27015", "--max-players", "6"])
	assert_true(c.is_server)
	assert_eq(c.port, 27015)
	assert_eq(c.max_players, 6)
	assert_eq(c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0)


func test_the_playtest_line_parses() -> void:
	var c := _parse(["--connect", "192.168.1.50:27015"])
	assert_true(c.should_autoconnect(), "--connect must skip the menu")
	assert_eq(c.connect_address, "192.168.1.50:27015")
	assert_eq(c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0)


func test_seed_and_record_and_tuning_parse() -> void:
	var c := _parse(["--seed", "12345", "--record", "run.log", "--tuning", "experiment"])
	assert_eq(c.seed_value, 12345)
	assert_eq(c.record_path, "run.log")
	assert_eq(c.tuning_profile, "experiment")


func test_no_seed_means_pick_one() -> void:
	assert_eq(_parse([]).seed_value, -1, "-1 is the 'no seed given' marker")


func test_an_unknown_flag_is_reported_not_ignored() -> void:
	# A typo'd --max-player silently running a 6-player lobby is how a playtest
	# gets invalidated without anyone realising it was misconfigured.
	var c := _parse(["--max-player", "5"])
	assert_eq(c.unknown.size(), 1, "the typo must be captured")
	assert_gt(c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0, "and must be an error")


func test_server_and_connect_together_are_refused() -> void:
	var c := _parse(["--server", "--connect", "127.0.0.1:27015"])
	var problems := c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD)
	assert_gt(problems.size(), 0, "a host that also dials out is a contradiction")


func test_a_malformed_connect_address_is_refused() -> void:
	var c := _parse(["--connect", "192.168.1.50"])
	assert_gt(
		c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0, "ip without :port must fail"
	)


func test_out_of_range_values_are_refused_not_clamped() -> void:
	# Clamping is the tempting behaviour and the wrong one. A silently corrected
	# port is a server nobody can find; a silently clamped lobby is a match that
	# differs from the one written on the playtest sheet.
	assert_gt(_parse(["--port", "80"]).problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0)
	assert_gt(
		_parse(["--max-players", "9"]).problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0
	)
	assert_gt(
		_parse(["--max-players", "2"]).problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0
	)


func test_a_flag_missing_its_value_does_not_crash() -> void:
	var c := _parse(["--port"])
	assert_eq(c.port, 0, "a missing value parses as 0")
	assert_gt(c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0, "and 0 is then rejected")


func test_the_live_tuning_agrees_with_the_test_constants() -> void:
	# Guards the guard. If TUN-LOBBY-MIN/MAX-PLAYERS ever change, every bound
	# above is testing numbers the game no longer uses.
	assert_eq(Tuning.match_rules.min_players, MIN_PLAYERS, "TUN-LOBBY-MIN-PLAYERS moved")
	assert_eq(Tuning.match_rules.max_players, MAX_PLAYERS, "TUN-LOBBY-MAX-PLAYERS moved")


# ------------------------------------- flags that are valid and inert --


## **A WARNING IS NOT A PROBLEM, AND THE DIFFERENCE IS WHETHER TO START.**
## `problems()` says *the launch is not what you asked for* and `boot.gd` refuses;
## this says *the launch is exactly what you asked for and one thing will be
## missing*. Refusing here would stop a playtest that is otherwise fine.
func test_record_is_valid_and_warns_that_it_does_nothing() -> void:
	var c := LaunchConfig.parse(["--server", "--record", "user://run.json"], 6)
	assert_eq(c.record_path, "user://run.json", "--record stopped parsing")
	assert_eq(
		c.problems(2, 6, MAX_CROWD).size(),
		0,
		"--record is a valid flag and must not refuse the launch"
	)
	assert_eq(c.warnings().size(), 1, "--record is read by nothing and said so to nobody")


## **THE SILENT CASE IS THE ONE THAT COSTS A SESSION.**
## `docs/40_backlog/playtests/README.md` tells a facilitator to attach the
## telemetry export; without this they find out it does not exist afterwards.
func test_a_launch_without_record_warns_about_nothing() -> void:
	var c := LaunchConfig.parse(["--server"], 6)
	assert_eq(c.warnings().size(), 0, "a clean command line produced a warning")


## **THE SECOND FLAG WITH `--record`'s SHAPE, FOUND 2026-09-04.** `tuning_profile`
## is parsed, validated and read by no code, and `data/tuning/` holds exactly one
## directory — so a session asking for other numbers silently runs the shipped
## ones. That is worse than the flag not existing, because it looks like it worked.
func test_tuning_is_valid_and_warns_that_it_does_nothing() -> void:
	var c := LaunchConfig.parse(["--server", "--tuning", "sandbox"], 6)
	assert_eq(c.tuning_profile, "sandbox", "--tuning stopped parsing")
	assert_eq(
		c.problems(2, 6, MAX_CROWD).size(),
		0,
		"--tuning is a valid flag and must not refuse the launch"
	)
	assert_eq(c.warnings().size(), 1, "--tuning is read by nothing and said so to nobody")


## The default must stay silent, or every launch in the project carries a warning
## and the channel stops being read.
func test_the_default_profile_warns_about_nothing() -> void:
	var c := LaunchConfig.parse(["--server", "--tuning", "default"], 6)
	assert_eq(c.warnings().size(), 0, "the shipped profile produced a warning")


## **`--map` REACHES A DEBUG-ONLY MAP AND THAT IS THE POINT.** `MAP-SANDBOX` is a
## bench; the flag is how you get onto it, and a shipped build cannot because the
## export presets do not carry it.
func test_map_selects_a_catalogued_map() -> void:
	var c := LaunchConfig.parse(["--server", "--map", "sandbox"], 6)
	assert_eq(c.map_name, "sandbox")
	assert_eq(c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0)


## **A TYPO'D MAP IS REFUSED, NOT FALLEN BACK FROM.** `MapCatalogue` falls back so
## that a caller who never saw a command line still gets a map; a launch that asked
## for one by name and silently got another is the shape of a playtest nobody
## realises was run on the wrong district.
func test_an_unknown_map_is_refused_and_the_message_lists_the_real_ones() -> void:
	var c := LaunchConfig.parse(["--server", "--map", "vetriao"], 6)
	var problems := c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD)
	assert_eq(problems.size(), 1, "a misspelled map was accepted")
	assert_string_contains(problems[0], "sandbox", "the message does not say what is available")


func test_the_default_map_needs_no_flag() -> void:
	var c := LaunchConfig.parse(["--server"], 6)
	assert_eq(c.map_name, MapCatalogue.DEFAULT)


## **-1 MEANS "WHATEVER THE TUNING SAYS" AND 0 IS A REAL ANSWER.** An empty district
## is a thing worth being able to ask for, so 0 cannot double as the sentinel.
func test_crowd_defaults_to_the_tuning_and_zero_is_askable() -> void:
	assert_eq(LaunchConfig.parse(["--server"], 6).crowd_count, -1)
	var empty := LaunchConfig.parse(["--server", "--crowd", "0"], 6)
	assert_eq(empty.crowd_count, 0)
	assert_eq(empty.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0, "0 must be legal")


func test_a_crowd_over_the_pool_is_refused() -> void:
	var c := LaunchConfig.parse(["--server", "--crowd", "500"], 6)
	assert_gt(
		c.problems(MIN_PLAYERS, MAX_PLAYERS, MAX_CROWD).size(), 0, "500 civilians was accepted"
	)
