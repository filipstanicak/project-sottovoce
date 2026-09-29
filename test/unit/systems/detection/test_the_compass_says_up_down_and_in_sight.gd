## **THE COMPASS SAYS UP OR DOWN, AND GLOWS IN SIGHT.** US-0105, ADR-0024.
##
## The reference's compass says *up* or *down* when its target is on another level
## and lights its whole disc while the target can be seen. Both are facts the server
## decides at the `detection` stage and sends as three bits beside the portrait
## latch. What this file holds is every hop: the rule, the pass that applies it, the
## byte that carries it, and the bridge that puts it on the bus.
extends GutTest

const HUNTER := 31
const PREY := 32

var _system: DetectionSystem
var _ctx: MatchContext
var _seen: Array = []


func before_each() -> void:
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_system.setup(_ctx)
	_place(HUNTER, Vector3.ZERO)
	_place(PREY, Vector3(0.0, 0.0, 10.0))
	_ctx.announced_contracts[HUNTER] = PREY
	_seen = []


func _place(peer: int, at: Vector3) -> void:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn


func _move_prey(to: Vector3) -> void:
	(_ctx.pawn_contexts[PREY] as PawnContext).position = to


func _resolve() -> void:
	_ctx.tick += 1
	_system.tick(_ctx, MatchContext.net_dt())


# --- the rule ------------------------------------------------------------------


func test_the_threshold_decides_up_down_and_level() -> void:
	var t := float(Tuning.compass.vertical_threshold)
	assert_eq(CompassBoard.vertical_for(t), CompassBoard.Vertical.UP, "at the threshold, up")
	assert_eq(CompassBoard.vertical_for(-t), CompassBoard.Vertical.DOWN, "at the threshold, down")
	assert_eq(CompassBoard.vertical_for(t - 0.01), CompassBoard.Vertical.LEVEL, "just under")
	assert_eq(CompassBoard.vertical_for(0.0), CompassBoard.Vertical.LEVEL)
	assert_eq(CompassBoard.Vertical.LEVEL, 0, "no vertical fact must be zero on the wire")


func test_a_hunter_with_no_reading_is_told_nothing() -> void:
	var board := CompassBoard.new()
	assert_eq(board.vertical_of(HUNTER), CompassBoard.Vertical.LEVEL)
	assert_false(board.sight_of(HUNTER))


# --- the pass ------------------------------------------------------------------


func test_a_contract_on_the_balcony_is_up_and_one_below_is_down() -> void:
	# GDD-05's strata: the street at 0, the balcony at 3.5 m.
	_move_prey(Vector3(0.0, 3.5, 10.0))
	_resolve()
	assert_eq(_ctx.compass.vertical_of(HUNTER), CompassBoard.Vertical.UP, "a balcony read level")
	(_ctx.pawn_contexts[HUNTER] as PawnContext).position = Vector3(0.0, 7.0, 0.0)
	_resolve()
	assert_eq(_ctx.compass.vertical_of(HUNTER), CompassBoard.Vertical.DOWN, "below read level")


func test_a_contract_on_a_stall_is_level() -> void:
	# A market stall is 0.9 m: a step, not another level.
	_move_prey(Vector3(0.0, 0.9, 10.0))
	_resolve()
	assert_eq(_ctx.compass.vertical_of(HUNTER), CompassBoard.Vertical.LEVEL)


func test_in_sight_is_ahead_in_range_and_not_behind_or_far() -> void:
	_resolve()
	assert_true(_ctx.compass.sight_of(HUNTER), "a contract 10 m ahead was not in sight")
	_move_prey(Vector3(0.0, 0.0, -10.0))
	_resolve()
	assert_false(_ctx.compass.sight_of(HUNTER), "a contract behind the hunter was in sight")
	_move_prey(Vector3(0.0, 0.0, Tuning.contract.pursuit_sight_range + 5.0))
	_resolve()
	assert_false(_ctx.compass.sight_of(HUNTER), "a contract out of range was in sight")


func test_the_builder_puts_both_on_the_hunters_snapshot() -> void:
	# **THROUGH THE REAL `SnapshotBuilder`**, which is the hop a hand-filled snapshot
	# would skip: a builder that forgot either field would leave every test above green.
	var ctx := MatchContext.new()
	var host := PawnHost.new()
	add_child_autofree(host)
	host.setup(ctx)
	var builder := SnapshotBuilder.new()
	add_child_autofree(builder)
	builder.setup(ctx, host, null)
	await get_tree().physics_frame
	ctx.slots.assign(HUNTER)
	host.spawn(HUNTER)
	ctx.compass.set_reading(HUNTER, 0.0, 20, 3.5)
	ctx.compass.set_sight(HUNTER, true)
	var snap := builder.build_for(HUNTER)
	assert_eq(snap.contract_vertical, CompassBoard.Vertical.UP, "the builder dropped up/down")
	assert_true(snap.contract_in_sight, "the builder dropped in-sight")


# --- the byte ------------------------------------------------------------------


func _round_trip(snap: Snapshot) -> Snapshot:
	var out := Snapshot.new()
	SnapshotCodec.read_compass_flags(out, SnapshotCodec.compass_flags(snap))
	return out


func test_every_combination_survives_the_byte() -> void:
	for portrait: bool in [false, true]:
		for vertical: int in [0, 1, 2]:
			for sight: bool in [false, true]:
				var snap := Snapshot.new()
				snap.portrait_revealed = portrait
				snap.contract_vertical = vertical
				snap.contract_in_sight = sight
				var back := _round_trip(snap)
				var label := "%s/%d/%s" % [portrait, vertical, sight]
				assert_eq(back.portrait_revealed, portrait, "portrait lost at " + label)
				assert_eq(back.contract_vertical, vertical, "vertical lost at " + label)
				assert_eq(back.contract_in_sight, sight, "sight lost at " + label)


func test_a_portrait_alone_is_the_byte_it_always_was() -> void:
	# **WHY EVERY FROZEN FIXTURE STILL READS THE SAME**: before version 6 the byte was
	# 0 or 1, and with nothing above or below and nobody in sight it still is.
	var snap := Snapshot.new()
	assert_eq(SnapshotCodec.compass_flags(snap), 0)
	snap.portrait_revealed = true
	assert_eq(SnapshotCodec.compass_flags(snap), 1)


# --- the bridge ----------------------------------------------------------------


func _on_compass(_b: float, _bucket: int, _lock: float, vertical: int, sight: bool) -> void:
	_seen.append([vertical, sight])


func test_the_bridge_puts_both_on_the_bus() -> void:
	var bridge := HudBridge.new()
	add_child_autofree(bridge)
	EventBus.compass_updated.connect(_on_compass)
	var snap := Snapshot.new()
	snap.distance_bucket = 20
	snap.contract_vertical = CompassBoard.Vertical.DOWN
	snap.contract_in_sight = true
	Net.snapshot_received.emit(snap)
	EventBus.compass_updated.disconnect(_on_compass)
	assert_eq(_seen, [[CompassBoard.Vertical.DOWN, true]], "the bus did not carry both facts")


# --- the word ------------------------------------------------------------------


func test_the_word_widget_can_only_say_up_down_or_nothing() -> void:
	# **THE COMPASS'S ONE TEXT, KEPT OUT OF `CompassWidget`** so that widget still
	# draws none (`test_compass_invents_nothing.gd`). What this one may draw is
	# exactly two string-table words, whatever value arrives.
	var up := Strings.get_text(&"ui.compass.up").to_upper()
	var down := Strings.get_text(&"ui.compass.down").to_upper()
	for value: int in [-1, 0, 1, 2, 3, 200]:
		assert_has(["", up, down], CompassWordWidget.word_for(value), "%d drew a word" % value)
	assert_eq(CompassWordWidget.word_for(CompassBoard.Vertical.UP), up)
	assert_eq(CompassWordWidget.word_for(CompassBoard.Vertical.DOWN), down)


func test_the_word_widget_formats_no_number() -> void:
	# The reason `CompassWidget` draws no text is that a distance must never reach the
	# screen as a number. This widget draws text, so it must hold nothing that could
	# turn a number into one.
	const WIDGET := "res://scripts/presentation/hud/compass_word_widget.gd"
	for forbidden: String in ["%d", "%f", "%.", "str(", "String.num", "bucket"]:
		assert_false(SourceScanner.code_contains(WIDGET, forbidden), "it holds `%s`" % forbidden)
