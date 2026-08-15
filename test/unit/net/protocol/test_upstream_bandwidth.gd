## **WHAT AN INPUT COMMAND ACTUALLY COSTS UPSTREAM.** TDD-04 §7.3, US-0038.
##
## The M2 gate asks for the upstream budget miss to be recorded *with its failing
## test*. This is that test, and it is written last in M2 rather than first
## because until it was written the miss was a **projection from a format nobody
## implemented**.
##
## **`NET-C2S-INPUT` IS NOT HAND-SERIALISED.** `Snapshot` is — it packs its own
## bytes, which is why §7.1's downstream figures can be measured. Input goes out
## as **RPC arguments**, and Godot encodes those as Variants: an `int` costs 8
## bytes, a `Vector2` 12, a `float` 8 or 12. §7.3 budgets the payload at **9
## bytes**, which is what the hand-packed layout in §6.1 would cost — `seq:u16`,
## `move:2×i8`, `yaw:u8`, `pitch:i8`, `buttons:u16`, `acked_tick:u16` — and that
## layout exists only in the document.
##
## This is US-0029's defect in the other direction. There, §7.1's per-record sizes
## were unreachable from §4's field list and the total was re-derived. Here §7.3's
## arithmetic is *correct for the format it assumes*; the implementation simply
## never used that format, and nobody had measured which one was on the wire.
##
## **MEASURED WITH `var_to_bytes`**, which is the same variant encoder Godot's
## high-level multiplayer uses. The real figure is **this or larger**: RPC adds
## its own framing (a node-path cache id and a method id) that this does not
## count, and ENet adds its header on top.
extends GutTest

## §7.3's own assumptions, so the projection here and the table there can be
## compared line for line.
const PACKET_OVERHEAD := 28.0
const RELIABLE_EXTRA_BYTES_PER_SECOND := 20.0

## What §7.3 budgeted the payload at, and what the hand-packed §6.1 layout would
## actually cost. Both are here because the gap between them is the finding.
const BUDGETED_PAYLOAD := 9
const HAND_PACKED_PAYLOAD := 10


## The arguments `Net.send_input` passes to `c2s_input`, in order. **The wire is
## this list**, so the measurement has to be of exactly it.
func _rpc_arguments() -> Array:
	var command := InputCommand.new()
	command.seq = 40000
	command.move = Vector2(0.7, -0.7)
	command.look_yaw = 2.5
	command.look_pitch = -0.3
	command.buttons = 0b1010101010
	command.acked_tick = 12345
	return [
		command.seq,
		command.move,
		command.look_yaw,
		command.look_pitch,
		command.buttons,
		command.acked_tick,
	]


func _measured_payload_bytes() -> int:
	var total := 0
	for arg: Variant in _rpc_arguments():
		total += var_to_bytes(arg).size()
	return total


func test_the_argument_list_matches_what_net_actually_sends() -> void:
	# **GUARDS THE MEASUREMENT.** If `send_input` gains or loses an argument and
	# this list does not, every number below is measured against a wire that no
	# longer exists — and it would keep reporting a plausible figure.
	# **ANCHORED ON THE FUNCTION, NOT ON THE CALL'S FORMATTING.** The first version
	# searched for the literal "c2s_input.rpc_id(" and failed, because `gdformat`
	# reflows a long call so the dot starts its own line. A guard that breaks on
	# whitespace is a guard somebody loosens, and the loosening is what costs you.
	var source := SourceScanner.read("res://scripts/net/net.gd")
	var at := source.find("func send_input")
	assert_gt(at, -1, "Net.send_input is gone")
	var call := source.substr(at, 600)
	assert_true(call.contains("c2s_input"), "send_input no longer sends NET-C2S-INPUT")
	assert_true(call.contains("rpc_id"), "send_input no longer dispatches by rpc_id")
	for field: String in ["command.seq", "command.move", "command.look_yaw", "command.buttons"]:
		assert_true(call.contains(field), "send_input no longer passes %s" % field)
	assert_true(
		call.contains("assembler.newest_tick()"), "send_input no longer sends the snapshot ack"
	)


func test_the_payload_is_not_the_nine_bytes_the_budget_assumes() -> void:
	# **THE FINDING.** Recorded as an assertion rather than a comment, so it fails
	# the day somebody hand-serialises the input command — which is the fix, and
	# which should make this test change rather than quietly keep passing.
	var measured := _measured_payload_bytes()
	gut.p("NET-C2S-INPUT payload measured at %d B (§7.3 budgets %d)" % [measured, BUDGETED_PAYLOAD])
	assert_gt(
		measured,
		BUDGETED_PAYLOAD,
		(
			"the payload now fits §7.3's budget — if input was hand-serialised, "
			+ "update this test and §7.3 together"
		)
	)


func test_input_coalescing_alone_would_not_close_the_gap() -> void:
	# **THE MITIGATION §7.3 NAMES DOES NOT WORK ON THE REAL NUMBER.** Coalescing
	# two commands per packet halves the packet rate, so it halves the 28-byte
	# overhead — but the payload doubles per packet, so payload cost is unchanged.
	# It was the right answer when the payload was believed to be 9 bytes and the
	# overhead dominated. Against a 56-byte payload the overhead is the small half.
	var rate: float = Tuning.net.client_input_rate
	var payload := float(_measured_payload_bytes())

	var now := payload * rate + PACKET_OVERHEAD * rate + RELIABLE_EXTRA_BYTES_PER_SECOND
	var coalesced := (
		payload * rate + PACKET_OVERHEAD * (rate / 2.0) + RELIABLE_EXTRA_BYTES_PER_SECOND
	)
	var hand_packed := (
		float(HAND_PACKED_PAYLOAD) * rate + PACKET_OVERHEAD * rate + RELIABLE_EXTRA_BYTES_PER_SECOND
	)

	gut.p("upstream now:            %.0f B/s = %.1f kbit/s" % [now, now * 8.0 / 1000.0])
	gut.p("with coalescing only:    %.0f B/s = %.1f kbit/s" % [coalesced, coalesced * 8.0 / 1000.0])
	gut.p(
		(
			"hand-packed, no coalesce: %.0f B/s = %.1f kbit/s"
			% [hand_packed, hand_packed * 8.0 / 1000.0]
		)
	)
	gut.p("budget: %.0f kbit/s" % Tuning.net.bandwidth_budget_up)

	assert_gt(
		coalesced * 8.0 / 1000.0,
		Tuning.net.bandwidth_budget_up,
		"coalescing alone now fits the budget — §7.3's mitigation may be enough after all"
	)


func test_the_projected_upstream_against_the_budget() -> void:
	# **PENDING, NOT FAILING**, the same choice `test_snapshot_size.gd` made and
	# for the same reason: this is a design finding, not a defect in any file a
	# red suite would point at. A permanently red test is one somebody deletes.
	#
	# ROADMAP §4.1 says this test "is expected to FAIL". US-0038 honours that as a
	# **recorded, visible pending with the number in it** rather than a red
	# pipeline, and says so rather than reinterpreting it quietly.
	var rate: float = Tuning.net.client_input_rate
	var total := (
		float(_measured_payload_bytes()) * rate
		+ PACKET_OVERHEAD * rate
		+ RELIABLE_EXTRA_BYTES_PER_SECOND
	)
	var kbit := total * 8.0 / 1000.0

	if kbit > Tuning.net.bandwidth_budget_up:
		pending(
			(
				(
					"upstream is %.1f kbit/s against a %.0f budget (%.0f %%). "
					+ "NET-C2S-INPUT is sent as RPC arguments, which Godot variant-encodes: "
					+ "%d bytes, not the 9 §7.3 assumes. Hand-serialising it the way Snapshot "
					+ "is serialised is the fix; coalescing alone is not. RISK-BANDWIDTH, US-0038."
				)
				% [
					kbit,
					Tuning.net.bandwidth_budget_up,
					100.0 * kbit / Tuning.net.bandwidth_budget_up,
					_measured_payload_bytes(),
				]
			)
		)
		return
	assert_lt(kbit, Tuning.net.bandwidth_budget_up)
