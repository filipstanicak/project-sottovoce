## The wire format round-trips, and carries nothing it must not. US-0029.
##
## **THE OMISSIONS ARE THE POINT.** GDD-03 forbids a hunter ever learning their
## contract's persona, exact position, elevation or tier. A rule that lives in a
## widget can be broken by a different widget; a rule that lives in the wire
## format cannot be broken at all — so the assertions that matter most here are
## about fields that do not exist.
extends GutTest

const COUNT_BYTES := 3


func _full() -> Snapshot:
	var snap := Snapshot.new()
	snap.server_tick = 123456
	snap.last_acked_seq = 4321
	snap.flags = 3
	snap.own_position = Vector3(12.34, 3.5, 98.76)
	snap.own_velocity = Vector3(-2.2, 0.0, 4.5)
	snap.own_state = PawnStateId.SPRINT
	snap.own_state_timer = 900
	snap.own_grounded = true
	snap.suspicion = 87.0
	snap.tier = 2
	snap.active_sources = 0b10101
	snap.cooldown_a_tick = 1200
	snap.cooldown_b_tick = 65535
	snap.blend_state = 9
	snap.kill_ready = true
	snap.stun_ready = false
	snap.bearing = 200
	snap.distance_bucket = 44
	snap.lock_fraction = 128
	snap.portrait_revealed = true
	snap.phase = 3
	snap.ticks_remaining = 7200
	snap.multiplier = 2
	snap.add_remote(2, Vector3(60.0, 3.5, 12.0), deg_to_rad(90.0), PawnStateId.STROLL, 33, 2)
	snap.add_npc(17, Vector3(-4.0, 3.5, 77.5), deg_to_rad(180.0), 5, 20)
	return snap


func test_a_snapshot_round_trips() -> void:
	var out := Snapshot.deserialise(_full().serialise())
	assert_not_null(out, "a snapshot did not decode at all")
	assert_eq(out.server_tick, 123456)
	assert_eq(out.last_acked_seq, 4321)
	assert_eq(out.own_state, PawnStateId.SPRINT, "the state index does not survive the wire")
	assert_eq(out.own_state_timer, 900)
	assert_true(out.own_grounded)


func test_the_own_pawn_block_is_not_quantised() -> void:
	# **THE PREDICTION AUTHORITY.** The client reconciles against this, and
	# reconciling against a value rounded to a centimetre would spend 1 cm of
	# `TUN-NET-RECONCILE-THRESHOLD`'s 10 cm budget on nothing at all.
	var out := Snapshot.deserialise(_full().serialise())
	assert_almost_eq(out.own_position.x, 12.34, 0.0001, "own position was quantised")
	assert_almost_eq(out.own_velocity.z, 4.5, 0.0001, "own velocity was quantised")


func test_the_packed_gameplay_byte_survives() -> void:
	# Six values in one byte: tier u2, blend u4, and two ready flags. A packing
	# error here decodes as a plausible tier, which is the worst kind of wrong.
	var out := Snapshot.deserialise(_full().serialise())
	assert_eq(out.tier, 2, "tier")
	assert_eq(out.blend_state, 9, "blend state")
	assert_true(out.kill_ready, "kill_ready — this drives the crosshair and must not lie")
	assert_false(out.stun_ready, "stun_ready")


func test_a_remote_pawn_round_trips_within_quantisation() -> void:
	var out := Snapshot.deserialise(_full().serialise())
	var record: Array = out.remote_pawns[0]
	assert_eq(record[0], 2, "the slot changed")
	assert_almost_eq((record[1] as Vector3).x, 60.0, Tuning.net.quant_pos, "position")
	assert_almost_eq(rad_to_deg(record[2] as float), 90.0, Quantise.YAW_STEP, "yaw")
	assert_eq(record[3], PawnStateId.STROLL, "state")
	assert_eq(record[4], 33, "anim phase")
	assert_eq(record[5], 2, "render state")


func test_an_npc_round_trips_within_quantisation() -> void:
	var out := Snapshot.deserialise(_full().serialise())
	var record: Array = out.npcs[0]
	assert_eq(record[0], 17, "the index changed")
	assert_almost_eq((record[1] as Vector3).z, 77.5, Tuning.net.quant_pos, "position")
	assert_eq(record[3], 5, "anim state")
	assert_eq(record[4], 20, "anim phase")


func test_an_npc_height_is_coarser_than_its_ground_position() -> void:
	# **DELIBERATE, AND THE REASON THE BUDGET CLOSES.** `x` and `z` keep their
	# centimetre because the crowd's horizontal position is read by the suspicion
	# radius and the compass; `y` is a byte at 5 cm because nothing reads a crowd
	# member's height at all, and the strata are 3.5 m apart.
	var snap := Snapshot.new()
	snap.add_npc(1, Vector3(10.0, 8.5, 20.0), 0.0, 1, 1)
	var record: Array = (Snapshot.deserialise(snap.serialise()) as Snapshot).npcs[0]
	var position := record[1] as Vector3
	assert_almost_eq(position.x, 10.0, Tuning.net.quant_pos, "x lost its centimetre")
	assert_almost_eq(position.y, 8.5, Quantise.HEIGHT_STEP, "the roof stratum did not survive")


func test_an_npc_animation_fits_one_byte() -> void:
	# `u3` state and `u5` phase. Eight anim states is more than the crowd
	# declares, and 32 phase steps is finer than a walk cycle can be read at the
	# 45-70 m these records are sent from.
	var snap := Snapshot.new()
	snap.add_npc(1, Vector3.ZERO, 0.0, 7, 31)
	var record: Array = (Snapshot.deserialise(snap.serialise()) as Snapshot).npcs[0]
	assert_eq(record[3], 7, "the top anim state did not survive")
	assert_eq(record[4], 31, "the top anim phase did not survive")


func test_an_empty_snapshot_still_decodes() -> void:
	# No remote pawns and no NPCs is the ordinary first tick of a match, not an
	# edge case.
	var out := Snapshot.deserialise(Snapshot.new().serialise())
	assert_not_null(out, "a snapshot with nobody in it did not decode")
	assert_eq(out.remote_pawns.size(), 0)
	assert_eq(out.npcs.size(), 0)


func test_a_truncated_snapshot_decodes_to_nothing() -> void:
	# **NOT A HALF-FILLED OBJECT.** A partial decode moves remote pawns to
	# plausible wrong places, which is worse than a frame with no update at all.
	var bytes := _full().serialise()
	assert_null(
		Snapshot.deserialise(bytes.slice(0, bytes.size() - 4)), "a truncated snapshot decoded"
	)
	assert_null(Snapshot.deserialise(PackedByteArray()), "an empty buffer decoded")


func test_a_retired_state_decodes_as_no_state() -> void:
	# `Jog` was removed in US-0090 and is absent from `ALL`. A peer on an older
	# build sending its old index must not become whatever now sits there.
	assert_eq(Snapshot.state_index(PawnStateId.JOG), Snapshot.NO_STATE)
	assert_eq(Snapshot.state_at(Snapshot.NO_STATE), &"")


# ------------------------------------------------------- what it does NOT say --


func test_the_snapshot_carries_no_persona_and_no_exact_contract_position() -> void:
	# GDD-03 §7: the hunter is never sent their contract's persona, position,
	# elevation or tier. Asserted structurally — the fields do not exist on the
	# object, so no builder can populate them and no widget can read them.
	var snap := Snapshot.new()
	for forbidden: String in [
		"contract_position",
		"contract_persona",
		"contract_tier",
		"contract_elevation",
		"contract_state"
	]:
		assert_false(forbidden in snap, "the snapshot has a `%s` field" % forbidden)


func test_the_compass_carries_a_bucket_rather_than_a_distance() -> void:
	# The imprecision is authored (design law 6) and applied SERVER-side. A client
	# given an exact distance could undo the bucketing; a client given the bucket
	# cannot.
	var snap := Snapshot.new()
	assert_true("distance_bucket" in snap, "the compass lost its bucket")
	assert_false("distance_metres" in snap, "the compass carries an exact distance")
	assert_false("contract_bearing_raw" in snap, "the compass carries an unwobbled bearing")


func test_render_state_is_two_bits_and_per_record() -> void:
	# **PER OBSERVER, NOT PER PLAYER.** The same player at the same suspicion is
	# PLAIN to four observers and HARD to one, so it belongs to the remote-pawn
	# record in each client's own snapshot rather than to any global state.
	var snap := Snapshot.new()
	snap.add_remote(1, Vector3.ZERO, 0.0, PawnStateId.IDLE, 0, 3)
	var out := Snapshot.deserialise(snap.serialise())
	assert_eq((out.remote_pawns[0] as Array)[5], 3, "render state lost its top value")
	assert_false("render_state" in snap, "render state is a global field")
