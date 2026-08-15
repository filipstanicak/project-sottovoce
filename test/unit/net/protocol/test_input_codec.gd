## **`NET-C2S-INPUT` ON THE WIRE.** US-0095, NETWORK_PROTOCOL §2, TDD-04 §7.3.
##
## The command went out as six loose RPC arguments until this codec existed, and
## Godot variant-encodes those at **56 bytes** against a §6.1 budget of nine —
## upstream at 253 % of `TUN-NET-BUDGET-UP`, measured at the M2 gate.
##
## **THE ONE PROPERTY THAT MATTERS IS LOSSLESSNESS FROM THE SAMPLER ONWARD.** The
## client predicts with the command it holds; the server simulates with the
## command it received. If those differ by a single rounding step the two diverge
## on **every frame** — quietly, because the reconciler would absorb it and the
## suite would stay green. `InputSampler` therefore quantises at sample time, and
## the round trip must be exact from there.
extends GutTest


## A command as the sampler would produce one: already quantised.
func _sampled(seq: int = 1234) -> InputCommand:
	var command := InputCommand.new()
	command.seq = seq
	command.move = InputCodec.quantise_move(Vector2(0.7, -0.35))
	command.look_yaw = InputCodec.quantise_yaw(2.1)
	command.look_pitch = InputCodec.quantise_pitch(-0.42)
	command.buttons = InputBits.RUN | InputBits.SCAN
	command.acked_tick = 40000
	return command


func test_a_sampled_command_survives_the_wire_exactly() -> void:
	# **THE ASSERTION THE FILE IS FOR.** Not "within a tolerance" — exactly. A
	# tolerance here would be a tolerance on client/server divergence.
	var sent := _sampled()
	var got := InputCodec.deserialise(InputCodec.serialise(sent))

	assert_not_null(got, "a well-formed command did not decode")
	assert_eq(got.seq, sent.seq, "seq did not survive")
	assert_eq(got.move, sent.move, "move did not survive exactly")
	assert_eq(got.look_yaw, sent.look_yaw, "yaw did not survive exactly")
	assert_eq(got.look_pitch, sent.look_pitch, "pitch did not survive exactly")
	assert_eq(got.buttons, sent.buttons, "buttons did not survive")
	assert_eq(got.acked_tick, sent.acked_tick, "the snapshot ack did not survive")


func test_quantising_twice_changes_nothing() -> void:
	# Idempotence is what makes "quantise at sample time" safe. If a second pass
	# moved the value, the sampler's accumulator and the wire would drift apart
	# over a match rather than immediately — the worst kind of bug to find.
	for radians: float in [0.0, 0.3, -1.9, PI - 0.001, -PI + 0.001]:
		var once := InputCodec.quantise_yaw(radians)
		assert_eq(InputCodec.quantise_yaw(once), once, "yaw quantisation is not idempotent")
	for radians: float in [0.0, 0.4, -1.2, 1.5, -1.5]:
		var once := InputCodec.quantise_pitch(radians)
		assert_eq(InputCodec.quantise_pitch(once), once, "pitch quantisation is not idempotent")


func test_the_quantisation_is_finer_than_anything_a_player_can_express() -> void:
	# **§6.1 DECLARES `yaw:u8` AND `pitch:i8`, AND THIS IS WHY THEY ARE NOT USED.**
	# 1.4° a step would make a slow mouse drag stick — a frame moving less than
	# half a step rounds back where it started — and the camera reads these values
	# directly, so it would stair-step. u16 costs nothing extra on the wire.
	var worst := 0.0
	for i: int in 400:
		var radians := -PI + TAU * float(i) / 400.0
		worst = maxf(worst, absf(InputCodec.quantise_yaw(radians) - radians))
	gut.p("worst yaw error: %.5f degrees" % rad_to_deg(worst))
	assert_lt(rad_to_deg(worst), 0.02, "yaw quantisation is coarse enough to feel")


func test_the_payload_is_twelve_bytes() -> void:
	assert_eq(InputCodec.serialise(_sampled()).size(), InputCodec.BYTES)
	assert_eq(InputCodec.BYTES, 12, "the declared layout changed without this test")


func test_twelve_bytes_costs_the_same_on_the_wire_as_ten() -> void:
	# **THE REASON THE LAYOUT IS NOT §6.1'S.** A `PackedByteArray` RPC argument
	# costs 8 bytes of Variant wrapper plus the payload rounded up to four, so
	# 9, 10, 11 and 12 bytes all cost 20. The two bytes §6.1's narrower fields
	# would save do not exist, and they would cost feel.
	assert_eq(
		InputCodec.wire_bytes(10), InputCodec.wire_bytes(12), "10 and 12 B differ on the wire"
	)
	assert_eq(InputCodec.wire_bytes(InputCodec.BYTES), 20, "the wire cost is not 20 B")


func test_a_buffer_of_the_wrong_size_is_refused() -> void:
	# **REFUSED, NOT PARTIALLY DECODED.** `StreamPeerBuffer` returns zero on an
	# over-read rather than failing, so a short buffer would decode as a command
	# holding no buttons and no movement — which the server would then simulate.
	assert_null(InputCodec.deserialise(PackedByteArray()), "an empty buffer decoded")
	var short := InputCodec.serialise(_sampled())
	short.resize(InputCodec.BYTES - 1)
	assert_null(InputCodec.deserialise(short), "a short buffer decoded")
	var long := InputCodec.serialise(_sampled())
	long.append(0)
	assert_null(InputCodec.deserialise(long), "an over-long buffer decoded")


func test_every_button_survives() -> void:
	# The bitfield is the whole of a client's intent — kill and stun are buttons.
	# One dropped bit is an input the server never sees.
	var command := _sampled()
	command.buttons = 0xFFFF
	assert_eq(InputCodec.deserialise(InputCodec.serialise(command)).buttons, 0xFFFF)


func test_the_sequence_wraps_rather_than_overflowing() -> void:
	# `seq` is a `u16` and wraps every ~18 minutes at 60 Hz — inside a match.
	# `SequenceGate.is_newer()` handles the wrap; the codec must produce it
	# rather than clamp, or the gate would see a stuck sequence instead.
	var command := _sampled(65536 + 5)
	assert_eq(InputCodec.deserialise(InputCodec.serialise(command)).seq, 5, "seq did not wrap")


func test_extreme_look_values_round_trip() -> void:
	# The wrap points are where an off-by-one in the mapping shows up, and a yaw
	# that flipped sign at ±PI would spin a pawn 180° once per revolution.
	for radians: float in [-PI, PI, 0.0]:
		var q := InputCodec.quantise_yaw(radians)
		var command := InputCommand.new()
		command.look_yaw = q
		var got := InputCodec.deserialise(InputCodec.serialise(command))
		assert_almost_eq(got.look_yaw, q, 0.0001, "yaw %f did not survive the wrap" % radians)

	for radians: float in [-PI / 2.0, PI / 2.0]:
		var q := InputCodec.quantise_pitch(radians)
		var command := InputCommand.new()
		command.look_pitch = q
		var got := InputCodec.deserialise(InputCodec.serialise(command))
		assert_almost_eq(got.look_pitch, q, 0.0001, "pitch %f did not survive the clamp" % radians)


func test_it_is_a_real_saving_against_the_loose_arguments() -> void:
	# Guards the reason this exists. If the wire cost ever climbed back toward
	# what six loose Variants cost, the codec is buying nothing.
	var loose := 0
	for arg: Variant in [1234, Vector2(0.7, -0.35), 2.1, -0.42, 6, 40000]:
		loose += var_to_bytes(arg).size()
	var packed := InputCodec.wire_bytes(InputCodec.BYTES)
	gut.p(
		(
			"loose args %d B -> packed %d B (%.0f %% saved)"
			% [loose, packed, 100.0 * (1.0 - float(packed) / float(loose))]
		)
	)
	assert_lt(packed * 2, loose, "the codec no longer even halves the cost")
