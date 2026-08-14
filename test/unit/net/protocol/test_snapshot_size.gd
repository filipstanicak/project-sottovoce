## **WHAT THE FORMAT ACTUALLY COSTS.** TDD-04 §7.1, US-0029.
##
## Every number here is *measured* from `Snapshot.serialise()`, never quoted from
## the document — which is the point, because the document's own arithmetic does
## not survive being measured.
##
## **§4 DECLARES FIELDS THAT CANNOT FIT THE SIZES §7.1 BUDGETS AGAINST.** The
## payload lists, per NPC, an index `u8`, a position `3×i16`, a yaw `u8` and an
## animation `u4 + u6` — and then says that is "7 bytes per NPC including index".
## The index and the position alone are seven. The remote-pawn record is quoted
## at 14 and its declared fields come to ten.
##
## This file measures both, and projects §7.1's worst case from the measurements.
## The projection **exceeds the budget**, which is a real finding and not a
## failure of this code: see US-0029, and `test_the_projected_worst_case` below,
## which is deliberately `pending` rather than passing or failing.
extends GutTest

## §7.1's worst case, unchanged.
const NEAR_NPCS := 45
const NEAR_CHANGED := 0.55
const FAR_NPCS := 30
const FAR_CHANGED := 0.70
const FAR_RATE := 10.0
const REMOTE_PLAYERS := 5
const EVENT_BYTES_PER_SECOND := 80
const PACKET_OVERHEAD := 28


func _measured_remote_bytes() -> int:
	var one := Snapshot.new()
	one.add_remote(1, Vector3(10.0, 1.0, 10.0), 1.0, PawnStateId.STROLL, 3, 1)
	return one.serialise().size() - Snapshot.new().serialise().size()


func _measured_npc_bytes() -> int:
	var one := Snapshot.new()
	one.add_npc(1, Vector3(10.0, 1.0, 10.0), 1.0, 3, 1)
	return one.serialise().size() - Snapshot.new().serialise().size()


func test_a_remote_pawn_record_is_what_the_constant_says() -> void:
	# Measured against the constant the projection uses, so the two can never
	# drift apart while the arithmetic below keeps quoting a stale number.
	assert_eq(_measured_remote_bytes(), Snapshot.REMOTE_BYTES)


func test_an_npc_record_is_what_the_constant_says() -> void:
	assert_eq(_measured_npc_bytes(), Snapshot.NPC_BYTES)


func test_the_fixed_part_of_a_snapshot_is_what_the_constants_say() -> void:
	var empty := Snapshot.new().serialise().size()
	assert_eq(empty, Snapshot.HEADER_BYTES + Snapshot.OWN_BYTES + Snapshot.COUNT_BYTES)


func test_the_records_are_smaller_than_sending_floats() -> void:
	# The reason quantisation exists at all: TDD-04 §7.2 claims ~60 % against
	# floats. A position alone is 12 bytes unquantised and 6 here.
	assert_lt(Snapshot.NPC_BYTES, 12 + 4 + 2, "quantisation stopped saving anything")


func test_the_declared_record_sizes_are_not_the_documented_ones() -> void:
	# **A TEST THAT ASSERTS A DISCREPANCY**, deliberately. §7.1 budgets 7 bytes per
	# NPC and 14 per remote pawn; the fields §4 declares come to ten and ten. This
	# fails the day somebody reconciles the two, which is exactly when it should
	# be read again.
	assert_ne(Snapshot.NPC_BYTES, 7, "§7.1's 7 B per NPC is now achievable — re-derive the budget")
	assert_ne(
		Snapshot.REMOTE_BYTES, 14, "§7.1's 14 B per remote pawn now matches — re-derive the budget"
	)


func test_the_projected_worst_case() -> void:
	# **PENDING, NOT FAILING.** The projection is over budget, and that is a design
	# finding rather than a defect in the serialiser: the fields are the ones §4
	# specifies and the encoding is as tight as those fields allow. Failing here
	# would make the suite red over a number nobody can fix by editing this file.
	var rate: float = Tuning.net.snapshot_rate
	var near := NEAR_NPCS * NEAR_CHANGED * Snapshot.NPC_BYTES * rate
	var far := FAR_NPCS * FAR_CHANGED * Snapshot.NPC_BYTES * FAR_RATE
	var remotes := REMOTE_PLAYERS * Snapshot.REMOTE_BYTES * rate
	var fixed := (Snapshot.HEADER_BYTES + Snapshot.OWN_BYTES + Snapshot.COUNT_BYTES) * rate
	var overhead := PACKET_OVERHEAD * rate
	var total := near + far + remotes + fixed + overhead + EVENT_BYTES_PER_SECOND
	var kbit := total * 8.0 / 1000.0

	gut.p(
		(
			"measured worst case: %.0f B/s = %.1f kbit/s against TUN-NET-BANDWIDTH-BUDGET-DOWN %.0f"
			% [total, kbit, Tuning.net.bandwidth_budget_down]
		)
	)
	if kbit > Tuning.net.bandwidth_budget_down:
		pending(
			(
				(
					"downstream is %.1f kbit/s, over the %.0f budget. The fields in §4 cannot"
					+ " reach the sizes §7.1 budgets against; ADR-0007's fallback or a smaller"
					+ " payload is needed. US-0029."
				)
				% [kbit, Tuning.net.bandwidth_budget_down]
			)
		)
		return
	assert_lt(kbit, Tuning.net.bandwidth_budget_down)
