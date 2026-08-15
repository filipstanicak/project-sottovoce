## `InputCommand` is the wire format, and its ten booleans are views onto one
## integer rather than ten fields beside it.
##
## Why that matters enough to test: if a flag could hold a value the bitfield
## did not, the server would simulate `buttons` while the client's prediction
## simulated the flag. They would agree in every unit test — both are set through
## the same setter — and diverge only under packet loss, in a way that reads as
## "the netcode is bad" rather than as a bug with a location.
extends GutTest


func test_the_layout_is_the_one_tdd_03_declares() -> void:
	# The field NAMES are the protocol. NETWORK_PROTOCOL §2 lists them by name,
	# and a rename here is a silent break for any peer on the older build.
	var command := InputCommand.new()
	var declared: Dictionary = {}
	for property: Dictionary in command.get_property_list():
		declared[property["name"]] = true

	var missing: PackedStringArray = []
	for field: String in ["seq", "move", "look_yaw", "look_pitch", "buttons", "acked_tick"]:
		if not declared.has(field):
			missing.append(field)
	assert_eq(missing.size(), 0, "InputCommand lost a wire field: " + ", ".join(missing))
	assert_eq(command.seq, 0)
	assert_eq(command.buttons, InputBits.NONE)
	assert_eq(command.move, Vector2.ZERO)


func test_every_view_reads_and_writes_its_own_bit() -> void:
	# Enumerated rather than spot-checked. A copy-paste error in one of eleven
	# near-identical accessors is exactly the defect a sample would miss, and it
	# would make two buttons the same button.
	var views := {
		"slow": InputBits.SLOW,
		"run": InputBits.RUN,
		"sprint": InputBits.SPRINT,
		"traverse": InputBits.TRAVERSE,
		"kill": InputBits.KILL,
		"stun": InputBits.STUN,
		"blend": InputBits.BLEND,
		"ability_1": InputBits.ABILITY_1,
		"ability_2": InputBits.ABILITY_2,
		"scan": InputBits.SCAN,
	}
	var wrong: PackedStringArray = []
	for field: String in views:
		var command := InputCommand.new()
		command.set(field, true)
		if command.buttons != views[field]:
			wrong.append("%s set %d, expected %d" % [field, command.buttons, views[field]])
		if not bool(command.get(field)):
			wrong.append("%s did not read back true" % field)
		command.set(field, false)
		if command.buttons != InputBits.NONE:
			wrong.append("%s left %d behind on clear" % [field, command.buttons])
	assert_eq(wrong.size(), 0, "\n".join(wrong))


func test_a_view_never_disturbs_another_bit() -> void:
	var command := InputCommand.new()
	command.slow = true
	command.kill = true
	command.slow = false
	assert_true(command.kill, "clearing slow cleared kill")
	assert_eq(command.buttons, InputBits.KILL)


func test_no_two_bits_collide() -> void:
	var seen: Dictionary = {}
	for bit: int in InputBits.ALL:
		assert_false(seen.has(bit), "two InputBits share value %d" % bit)
		assert_lt(bit, 1 << (InputBits.MAX_BIT + 1), "bit %d does not fit the u16 wire field" % bit)
		seen[bit] = true
	assert_eq(seen.size(), InputBits.ALL.size())


func test_newly_pressed_reports_edges_and_not_holds() -> void:
	# The server receives HELD state at 30 Hz, having missed frames. Edges are
	# derived, never transmitted; a press that arrived as an event would be lost
	# the moment one packet was.
	var held := InputBits.KILL | InputBits.SLOW
	assert_eq(InputBits.newly_pressed(held, InputBits.SLOW), InputBits.KILL)
	assert_eq(InputBits.newly_pressed(held, held), InputBits.NONE)
	assert_eq(InputBits.newly_pressed(InputBits.NONE, held), InputBits.NONE)


func test_empty_carries_the_sequence_number() -> void:
	var command := InputCommand.empty(42)
	assert_eq(command.seq, 42)
	assert_eq(command.buttons, InputBits.NONE)


func test_a_duplicate_shares_nothing() -> void:
	var original := InputCommand.empty(7)
	original.move = Vector2(0.5, 0.5)
	original.look_yaw = 1.25
	original.sprint = true
	var copy := original.duplicate_command()

	original.sprint = false
	original.move = Vector2.ZERO
	assert_true(copy.sprint, "the copy followed the original's buttons")
	assert_eq(copy.move, Vector2(0.5, 0.5), "the copy followed the original's move")
	assert_eq(copy.seq, 7)
	assert_eq(copy.look_yaw, 1.25)


func test_the_client_supplied_tick_is_marked_forgeable_where_someone_will_read_it() -> void:
	# **THE FIELD CHANGED JOBS IN US-0031; THE WARNING ON IT DID NOT.** It was
	# `client_tick`, advisory-only per ADR-0010 and provably a duplicate of `seq`;
	# it is `acked_tick` now and carries the delta baseline. What survives the
	# rename is the reason the warning exists: **it is client-supplied and
	# therefore forgeable**, and a contest resolved on a forgeable number is a
	# contest the attacker wins.
	#
	# The warning has to be at the field, because that is where it will be read by
	# whoever is tempted to order something by it.
	var text := SourceScanner.read("res://scripts/pawn/input_command.gd")
	var at := text.find("var acked_tick")
	assert_gt(at, -1, "InputCommand lost acked_tick")
	var docstring := text.substr(maxi(0, at - 1200), 1200)
	assert_true(docstring.to_lower().contains("forgeable"), "acked_tick is not marked forgeable")
	assert_true(docstring.contains("ADR-0010"), "acked_tick does not cite ADR-0010")


func test_a_forged_ack_can_only_cost_the_liar_bandwidth() -> void:
	# **WHY REPURPOSING THIS FIELD IS SAFE**, stated where it can fail. A lying
	# client can name any baseline it likes. The worst outcomes are: a full
	# snapshot it did not need, or a delta it cannot assemble — which it then
	# fails to acknowledge, so the server falls back to full. Neither reaches
	# another player, and neither orders an event.
	var text := SourceScanner.read("res://scripts/pawn/input_command.gd")
	var at := text.find("var acked_tick")
	var docstring := text.substr(maxi(0, at - 1200), 1200)
	assert_true(
		docstring.to_lower().contains("never used to order"),
		"acked_tick no longer states that it orders nothing"
	)


func test_wants_movement_is_what_decides_idle() -> void:
	var command := InputCommand.new()
	assert_false(command.wants_movement())
	command.move = Vector2(0.0, 0.01)
	assert_true(command.wants_movement(), "a small stick deflection still moves")
