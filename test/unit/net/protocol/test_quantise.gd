## Position and yaw on the wire. US-0029.
##
## Every conversion is asserted as a **round trip within its own step**, never
## against a hand-computed integer: the step is a tunable, and a test that pinned
## `1234` would fail the day `TUN-NET-QUANT-POS` moved while proving nothing
## about whether the encoding is lossless enough.
extends GutTest


func test_a_position_survives_within_a_centimetre() -> void:
	for metres: float in [0.0, 0.005, 1.0, -1.0, 59.994, -120.0, 327.0]:
		var back := Quantise.i16_to_pos(Quantise.pos_to_i16(metres))
		assert_almost_eq(back, metres, Tuning.net.quant_pos, "%f did not survive" % metres)


func test_the_whole_district_fits_the_encoding() -> void:
	# **THE FAILURE MODE IS SILENT WRAPAROUND**, not an error: a pawn at a
	# position too large for an `i16` appears on the opposite side of the map.
	# MAP-VETRAIO is 120 m square, so this has enormous margin — and the margin is
	# what the guard is for, because the next map might not.
	for corner: Vector3 in [
		Vector3.ZERO,
		Vector3(120.0, 0.0, 120.0),
		Vector3(120.0, 12.0, 0.0),
		Vector3(-120.0, 0.0, -120.0)
	]:
		assert_true(Quantise.fits(corner), "%v does not fit the wire encoding" % corner)


func test_a_position_past_the_edge_clamps_rather_than_wraps() -> void:
	# One of those is debuggable and the other puts a pawn in the opposite corner.
	assert_eq(Quantise.pos_to_i16(9999.0), Quantise.I16_MAX)
	assert_eq(Quantise.pos_to_i16(-9999.0), Quantise.I16_MIN)


func test_a_yaw_survives_within_a_step() -> void:
	for degrees: float in [0.0, 1.0, 89.5, 180.0, 270.0, 359.9]:
		var back := rad_to_deg(Quantise.u8_to_yaw(Quantise.yaw_to_u8(deg_to_rad(degrees))))
		var error := absf(fposmod(back - degrees + 180.0, 360.0) - 180.0)
		assert_lt(error, Quantise.YAW_STEP, "%f° did not survive" % degrees)


func test_yaw_wraps_rather_than_clamping() -> void:
	# Yaw is periodic: 361° and 1° are the same heading, and there is no edge to
	# pin to. A clamp would make a pawn turning past north stop turning.
	assert_eq(
		Quantise.yaw_to_u8(deg_to_rad(361.0)),
		Quantise.yaw_to_u8(deg_to_rad(1.0)),
		"361° and 1° encoded differently"
	)
	assert_eq(
		Quantise.yaw_to_u8(deg_to_rad(-1.0)),
		Quantise.yaw_to_u8(deg_to_rad(359.0)),
		"a negative yaw did not wrap"
	)


func test_the_yaw_byte_never_leaves_a_byte() -> void:
	for degrees: int in range(0, 720, 7):
		var byte := Quantise.yaw_to_u8(deg_to_rad(float(degrees)))
		assert_between(byte, 0, 255, "%d° encoded outside a byte" % degrees)


func test_suspicion_rounds_rather_than_truncating() -> void:
	# A tier boundary sits at an integer. Truncation would put the client one
	# point below the server for the whole approach to it — and the tier
	# indicator would change a tick late, every time.
	assert_eq(Quantise.suspicion_to_u8(59.6), 60)
	assert_eq(Quantise.suspicion_to_u8(59.4), 59)


func test_packing_two_fields_into_a_byte_is_reversible() -> void:
	for high: int in range(0, 4):
		for low: int in range(0, 64):
			var byte := Quantise.pack(high, 2, low, 6)
			assert_eq(Quantise.unpack_high(byte, 6, 2), high, "high half of %d" % byte)
			assert_eq(Quantise.unpack_low(byte, 6), low, "low half of %d" % byte)


func test_an_oversized_field_cannot_corrupt_its_neighbour() -> void:
	# **THE WORST KIND OF WRONG.** A render_state of 7 in a two-bit field would
	# otherwise spill into the animation phase and decode as a plausible number.
	var byte := Quantise.pack(63, 6, 7, 2)
	assert_eq(Quantise.unpack_high(byte, 2, 6), 63, "the high field was damaged")
	assert_eq(Quantise.unpack_low(byte, 2), 3, "the low field did not mask")
