## **`ticks_remaining` GETS ITS FIRST WRITER, AFTER FIVE MILESTONES ON THE WIRE.**
## US-0079.
##
## The field has been in `Snapshot` and in NETWORK_PROTOCOL §4 since M0 and nothing
## under `scripts/` had ever assigned it, so every client of every match has been
## told **zero ticks left**. Nothing drew it, which is the only reason it was
## survivable and exactly why nobody noticed: a field nobody reads and nobody writes
## is indistinguishable from one that works.
##
## **THIS FILE IS THE SEAM RATHER THAN THE RULE.** What the clock says is
## `test_match_system.gd`'s and is not re-proven here; what this asserts is that the
## answer reaches the format — the hop that US-0074 lost a whole integration run to,
## and that left `NET-C2S-ABILITY-REQUEST` with no caller under three completed
## stories.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const ALICE := 51

var _ctx: MatchContext
var _host: PawnHost
var _builder: SnapshotBuilder
var _match: MatchSystem


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_match = MatchSystem.new()
	_match.setup(_ctx, Tuning.match_rules)
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.match_state = _match
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame
	_ctx.slots.assign(ALICE)
	_host.spawn(ALICE)


func test_the_first_tick_of_play_carries_the_whole_match() -> void:
	var whole := MatchClock.ticks_of(Tuning.match_rules.duration, Tuning.match_rules)
	assert_gt(whole, 0, "the match converted to no ticks at all")
	assert_eq(_builder.build_for(ALICE).ticks_remaining, whole, "the wire carried no clock")


func test_the_clock_on_the_wire_counts_down_with_the_phase() -> void:
	_match.phase_elapsed = 90
	var whole := MatchClock.ticks_of(Tuning.match_rules.duration, Tuning.match_rules)
	assert_eq(
		_builder.build_for(ALICE).ticks_remaining,
		whole - 90,
		"three seconds of play did not come off the clients' clock"
	)


## **THE FIELD IS `u16` AND THE MATCH IS 14 400 TICKS**, so it fits — with room. Said
## as an assertion rather than as arithmetic in a comment, because the day
## `TUN-MATCH-DURATION` reaches its `@export_range` ceiling of 600 s this is 18 000
## and still fits, and the day somebody raises that range it stops.
func test_the_whole_match_fits_the_wire_field() -> void:
	var whole := MatchClock.ticks_of(Tuning.match_rules.duration, Tuning.match_rules)
	assert_lt(whole, 65536, "Snapshot.ticks_remaining is a u16 and the match is longer")
	var wire := Snapshot.deserialise(_builder.build_for(ALICE).serialise())
	assert_eq(wire.ticks_remaining, whole, "the clock did not survive the round trip")


## **THE LOBBY HAS NO CLOCK AND THE WIRE CANNOT CARRY `NO_CLOCK`.** A `u16` has no
## room for -1, so the builder clamps — which is right, and is why the *phase* is the
## field a client reads first: zero ticks left in `LOBBY` means there is nothing to
## count, and zero in `FINAL` means the match is over.
func test_the_lobby_sends_no_countdown() -> void:
	_ctx.phase = MatchPhase.Phase.LOBBY
	assert_eq(_builder.build_for(ALICE).ticks_remaining, 0, "the lobby put a clock on the wire")


func test_the_multiplier_reaches_the_wire_when_the_final_contract_opens() -> void:
	var rules := Tuning.match_rules
	assert_eq(_builder.build_for(ALICE).multiplier, 1, "ordinary play announced a multiplier")
	_ctx.phase = MatchPhase.Phase.FINAL
	_ctx.active_started_at = 0
	_ctx.tick = MatchClock.final_opens_at(rules)
	assert_eq(
		_builder.build_for(ALICE).multiplier,
		int(round(rules.finalphase_mult)),
		"the Final Contract was never announced to the client"
	)


## **THE RESULTS SCREEN COUNTS DOWN ON ITS OWN CLOCK, AND IT REACHES THE CLIENT.**
## Both halves are needed and only one was true until 2026-09-09: the builder filled
## the field correctly, and `MatchDirector` never emitted the tick that sends it, so
## the whole phase went out on nobody's wire. `test_match_director.gd` owns the second
## half; this owns the first.
func test_the_results_phase_carries_its_own_countdown() -> void:
	var rules := Tuning.match_rules
	_ctx.phase = MatchPhase.Phase.RESULTS
	_match.phase_elapsed = 30
	var whole := MatchClock.ticks_of(rules.results_duration, rules)
	assert_gt(whole, 30, "TUN-MATCH-RESULTS-DURATION converted to almost no ticks")
	assert_eq(
		_builder.build_for(ALICE).ticks_remaining,
		whole - 30,
		"the results screen does not count its own duration down"
	)


## And a skipped results screen reads zero, which is how the unanimous vote ends the
## screen at all — `MatchSystem` runs the phase clock out rather than changing phase.
func test_a_skipped_results_screen_reads_zero_on_the_wire() -> void:
	_ctx.phase = MatchPhase.Phase.RESULTS
	_match.phase_elapsed = MatchClock.duration_ticks(MatchPhase.Phase.RESULTS, Tuning.match_rules)
	assert_eq(_builder.build_for(ALICE).ticks_remaining, 0, "a spent results clock did not read 0")


## **A BUILDER WITH NO `SYS-MATCH` IS LEGAL AND SAYS ZERO**, the same call every
## snapshot test written before this story makes. The alternative is a null
## dereference in the one code path that runs thirty times a second per player.
func test_a_builder_with_no_match_system_still_builds() -> void:
	_builder.match_state = null
	assert_eq(_builder.build_for(ALICE).ticks_remaining, 0, "a clockless server invented a clock")
