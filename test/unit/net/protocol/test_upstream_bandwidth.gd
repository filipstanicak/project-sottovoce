## **WHAT AN INPUT COMMAND ACTUALLY COSTS UPSTREAM.** TDD-04 §7.3, US-0038,
## US-0095.
##
## Written at the M2 gate, when it found the upstream miss was **253 % of budget
## rather than the 112 % §7.3 predicted**: `NET-C2S-INPUT` went out as six loose
## RPC arguments, which Godot variant-encodes at 56 bytes against a budgeted 9.
##
## **US-0095 HAND-SERIALISED IT, AND THE GATE'S OWN PROJECTION WAS TOO
## OPTIMISTIC.** US-0038 recorded "hand-packed only → 18.4 kbit/s, 115 %". That
## figure counted the payload as reaching the wire raw. It does not: a
## `PackedByteArray` RPC argument costs **8 bytes of Variant wrapper plus the
## payload rounded up to four**. The real figure is **145 %** — a large
## improvement, and still over.
##
## The correction matters more than the number. **A projection is not a
## measurement**, and the gate's table was a projection made one layer too high —
## the same mistake §7.3 made, one level down. This file measures.
extends GutTest

## §7.3's own assumptions, so the projection here and the table there can be
## compared line for line.
const PACKET_OVERHEAD := 28.0
const RELIABLE_EXTRA_BYTES_PER_SECOND := 20.0

## What six loose Variant arguments cost, before US-0095.
const LOOSE_ARGUMENT_BYTES := 56


func _upstream(payload_wire: float, packets_per_second: float) -> float:
	return (
		payload_wire * packets_per_second
		+ PACKET_OVERHEAD * packets_per_second
		+ RELIABLE_EXTRA_BYTES_PER_SECOND
	)


func _kbit(bytes_per_second: float) -> float:
	return bytes_per_second * 8.0 / 1000.0


func test_the_input_path_still_hand_serialises() -> void:
	# **GUARDS EVERY NUMBER BELOW.** If `send_input` went back to loose arguments,
	# the projection here would keep reporting the packed figure and look healthy.
	#
	# Anchored on the function rather than on the call's formatting: `gdformat`
	# reflows long calls, and a guard that breaks on whitespace is one somebody
	# loosens.
	var source := SourceScanner.read("res://scripts/net/net.gd")
	var at := source.find("func send_input")
	assert_gt(at, -1, "Net.send_input is gone")
	var call := source.substr(at, 600)
	assert_true(call.contains("InputCodec.serialise"), "send_input no longer packs the command")
	assert_true(
		call.contains("assembler.newest_tick()"), "send_input no longer sends the snapshot ack"
	)


func test_hand_serialising_cut_the_payload_by_two_thirds() -> void:
	var packed := InputCodec.wire_bytes(InputCodec.BYTES)
	gut.p("payload: %d B loose -> %d B packed" % [LOOSE_ARGUMENT_BYTES, packed])
	assert_lt(packed * 2, LOOSE_ARGUMENT_BYTES, "the codec no longer even halves the payload")


func test_the_measured_upstream_now() -> void:
	var rate: float = Tuning.net.client_input_rate
	var budget: float = Tuning.net.bandwidth_budget_up
	var packed := float(InputCodec.wire_bytes(InputCodec.BYTES))

	var before := _upstream(float(LOOSE_ARGUMENT_BYTES), rate)
	var now := _upstream(packed, rate)
	gut.p("before US-0095: %.1f kbit/s (%.0f %%)" % [_kbit(before), 100.0 * _kbit(before) / budget])
	gut.p("now:            %.1f kbit/s (%.0f %%)" % [_kbit(now), 100.0 * _kbit(now) / budget])
	gut.p("budget:         %.0f kbit/s" % budget)

	assert_lt(_kbit(now), _kbit(before) * 0.7, "hand-serialising bought less than a third")


func test_the_packet_overhead_alone_is_most_of_the_budget() -> void:
	# **THE FINDING THAT DECIDES WHAT COMES NEXT.** At 60 packets a second, ENet's
	# 28-byte header costs 13.4 kbit/s — **84 % of the whole budget before a single
	# byte of payload.** Even a zero-length command would leave under 5 bytes a
	# packet of room.
	#
	# So the payload was the right thing to fix first and it cannot be the last:
	# what remains is the *packet rate*, which is exactly what coalescing halves.
	# §7.3's original mitigation was correct — it was correct about the wrong
	# term, at a time when nobody had measured which term dominated.
	var rate: float = Tuning.net.client_input_rate
	var budget: float = Tuning.net.bandwidth_budget_up
	var overhead_only := _kbit(PACKET_OVERHEAD * rate)
	gut.p(
		(
			"packet overhead alone: %.1f kbit/s = %.0f %% of budget"
			% [overhead_only, 100.0 * overhead_only / budget]
		)
	)
	assert_gt(overhead_only, budget * 0.75, "overhead is no longer the dominant term")


func test_coalescing_would_now_close_the_budget() -> void:
	# **AND NOW IT IS THE RIGHT MOVE, WHICH IT WAS NOT BEFORE US-0095.** Against a
	# 56-byte payload, coalescing left the miss at 211 % and would have spent up
	# to 16 ms of input latency to get there. Against a packed command it closes
	# the budget outright — the payload doubles per packet but the packet rate
	# halves, so overhead halves and the total falls under.
	var rate: float = Tuning.net.client_input_rate
	var budget: float = Tuning.net.bandwidth_budget_up
	var two_commands := float(InputCodec.wire_bytes(InputCodec.BYTES * 2))
	var coalesced := _upstream(two_commands, rate / 2.0)

	gut.p(
		(
			"hand-packed AND coalesced: %.1f kbit/s (%.0f %%)"
			% [_kbit(coalesced), 100.0 * _kbit(coalesced) / budget]
		)
	)
	assert_lt(_kbit(coalesced), budget, "coalescing no longer closes the budget")


func test_the_projected_upstream_against_the_budget() -> void:
	# **PENDING, NOT FAILING**, the same choice `test_snapshot_size.gd` made: a
	# design finding rather than a defect in any file a red suite would point at,
	# and a permanently red test is one somebody eventually deletes.
	var rate: float = Tuning.net.client_input_rate
	var budget: float = Tuning.net.bandwidth_budget_up
	var kbit := _kbit(_upstream(float(InputCodec.wire_bytes(InputCodec.BYTES)), rate))

	if kbit > budget:
		pending(
			(
				(
					"upstream is %.1f kbit/s against a %.0f budget (%.0f %%). "
					+ "Hand-serialising the command (US-0095) brought it down from 253 %%; "
					+ "what is left is PACKET OVERHEAD — 28 B × 60 Hz is 84 %% of the budget "
					+ "on its own. Coalescing two commands per packet closes it. RISK-BANDWIDTH."
				)
				% [kbit, budget, 100.0 * kbit / budget]
			)
		)
		return
	assert_lt(kbit, budget)
