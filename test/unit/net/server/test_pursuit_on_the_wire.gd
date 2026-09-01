## **BOTH SIDES OF A CHASE, TO THE ONE PLAYER EACH IS ABOUT.** US-0097's last
## criterion, ADR-0014.
##
## **THE FIXTURE IS BUILT SO A TRANSPOSITION IS VISIBLE.** Two bytes of the same
## width holding two fractions of the same bar is the shape `ScoreAward` was
## extracted to avoid, and there is no type here that separates them — so Alice is
## made a hunter *and* a prey at once, with the two bars at deliberately different
## values. Equal fixtures would agree whichever way round the bytes were written.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const ALICE := 41
const BOB := 42
const CAROL := 43

var _ctx: MatchContext
var _host: PawnHost
var _builder: SnapshotBuilder
var _full: int = 0


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame
	for peer: int in [ALICE, BOB, CAROL]:
		_ctx.slots.assign(peer)
		_host.spawn(peer)
	_full = Tuning.ticks(&"TUN-PURSUIT-DURATION")


func test_the_window_is_a_real_number_of_ticks() -> void:
	# **THE PREMISE.** Every fraction below is a division by this, so a zero would
	# make the whole file assert that nothing is ever drawn — vacuously, and green.
	assert_gt(_full, 60, "TUN-PURSUIT-DURATION converted to no ticks worth having")


func test_a_hunter_is_told_their_own_bar() -> void:
	_ctx.pursuit.refresh(ALICE, BOB, _full)
	assert_eq(_builder.build_for(ALICE).hunt_fraction, 255)


func test_the_prey_is_told_the_bar_being_run_against_them() -> void:
	_ctx.pursuit.refresh(ALICE, BOB, _full)
	assert_eq(_builder.build_for(BOB).hunted_fraction, 255)


func test_a_hunter_is_not_told_they_are_being_hunted_when_they_are_not() -> void:
	_ctx.pursuit.refresh(ALICE, BOB, _full)
	assert_eq(_builder.build_for(ALICE).hunted_fraction, 0)
	assert_eq(_builder.build_for(BOB).hunt_fraction, 0)


func test_a_player_in_no_chase_at_all_reads_zero_both_ways() -> void:
	_ctx.pursuit.refresh(ALICE, BOB, _full)
	var carol := _builder.build_for(CAROL)
	assert_eq(carol.hunt_fraction, 0)
	assert_eq(carol.hunted_fraction, 0)


## **THE TWO BARS ARE NOT THE SAME BAR, AND THIS IS THE ASSERTION THAT SAYS SO.**
## A Hamiltonian cycle makes every player a hunter and a prey simultaneously, so
## the interesting case is not an edge case: Alice is chasing Bob at full while
## Carol is chasing Alice at a quarter, and one byte could not have carried both.
func test_a_player_hunting_and_hunted_at_once_gets_two_different_numbers() -> void:
	_ctx.pursuit.refresh(ALICE, BOB, _full)
	_ctx.pursuit.refresh(CAROL, ALICE, _full / 4)
	var alice := _builder.build_for(ALICE)
	assert_eq(alice.hunt_fraction, 255, "Alice's own chase is full and read as something else")
	assert_almost_eq(alice.hunted_fraction, 64, 2, "the chase on Alice read as her own")


## **`NOBODY` IS ZERO AND ZERO IS A DICTIONARY KEY LIKE ANY OTHER.** No engine peer
## id is ever 0, so the reverse lookup would miss anyway — and resting the rule on
## that is `CompassBoard.NO_CONTRACT`'s hazard exactly. Deleting the explicit guard
## in `_fill_pursuit` reddens this and nothing else in the suite.
func test_a_chase_keyed_on_nobody_is_not_handed_to_everybody() -> void:
	_ctx.pursuit.refresh(ContractCycle.NOBODY, BOB, _full)
	assert_eq(
		_builder.build_for(CAROL).hunted_fraction,
		0,
		"a player with no pursuer was handed the NOBODY row's bar"
	)


func test_the_bytes_survive_the_wire_the_right_way_round() -> void:
	_ctx.pursuit.refresh(ALICE, BOB, _full)
	_ctx.pursuit.refresh(CAROL, ALICE, _full / 4)
	var sent := _builder.build_for(ALICE)
	var back := Snapshot.deserialise(sent.serialise())
	assert_not_null(back, "the snapshot did not decode")
	assert_eq(back.hunt_fraction, sent.hunt_fraction)
	assert_eq(back.hunted_fraction, sent.hunted_fraction)
	assert_ne(back.hunt_fraction, back.hunted_fraction, "the fixture stopped being asymmetric")


## The one byte the format grew, twice. **`OWN_BYTES` is asserted rather than
## trusted**: `test_snapshot_size.gd` measures an empty snapshot against the
## constants, so the two would disagree — this says which way and why.
func test_the_own_block_grew_by_exactly_two_bytes() -> void:
	assert_eq(Snapshot.OWN_BYTES, 45, "the pursuit bars are two bytes and no more")
