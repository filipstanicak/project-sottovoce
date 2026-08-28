## **`NET-S2C-SCORE-EVENT` SURVIVES THE WIRE, AND ITS KIND BYTES ARE FROZEN.**
## `NETWORK_PROTOCOL.md` §4, US-0074.
##
## Two properties that fail differently. A round trip that loses a field is loud;
## **a reordered `ScoreKinds.ALL` is silent** — every packet still decodes, every
## test of the feed still passes, and the feed simply draws `Patient` where the
## server paid `Focus`. That is the one this file exists for.
extends GutTest

const RULES_TICK := 10


func _event(kind: StringName, points: float, group: int = 3) -> ScoreEvent:
	return ScoreEvent.new(
		41, ScoreAward.new(RULES_TICK, kind, 7, 8, points), Tuning.match_rules, group
	)


func test_a_row_is_the_declared_sixteen_bytes() -> void:
	# The catalogue's row is `u32, u32, u8, u8, u8, i16, u8, u16`. A row that grew a
	# field would decode as garbage from the field after it.
	assert_eq(ScoreWire.pack(_event(Ids.SCORE_SILENT, 200.0), 1, 2).size(), ScoreWire.SIZE)
	assert_eq(ScoreWire.SIZE, 16, "the declared row width changed")


func test_a_round_trip_keeps_the_kind_the_points_and_the_group() -> void:
	var report := ScoreWire.unpack(ScoreWire.pack(_event(Ids.SCORE_BLENDED, 200.0, 9), 1, 2))
	assert_not_null(report)
	assert_eq(report.kind, Ids.SCORE_BLENDED)
	assert_eq(report.points, 200)
	assert_eq(report.group, 9)


func test_every_kind_survives_a_round_trip() -> void:
	# **THE PREMISE FOR THE ORDERING TEST BELOW.** An `ALL` missing an id would send
	# `UNKNOWN` and the feed would draw nothing for a bonus the server paid.
	for kind: StringName in ScoreKinds.ALL:
		var report := ScoreWire.unpack(ScoreWire.pack(_event(kind, 50.0), 1, 2))
		assert_eq(report.kind, kind, "%s did not survive the wire" % kind)


func test_the_wire_ordering_is_frozen() -> void:
	# **APPEND ONLY. NEVER REORDER.** These bytes are decoded by a client that may
	# have been built against this list; moving a row renames every bonus at once
	# with nothing failing. Adding to the end is legal and does not touch this.
	var head: Array[StringName] = [
		Ids.SCORE_CONTRACT,
		Ids.SCORE_SILENT,
		Ids.SCORE_PATIENT,
		Ids.SCORE_MASKED,
		Ids.SCORE_FOCUS,
		Ids.SCORE_FROMABOVE,
		Ids.SCORE_BLENDED,
	]
	for i: int in head.size():
		assert_eq(ScoreKinds.ALL[i], head[i], "wire byte %d changed meaning" % i)


func test_the_multiplier_is_carried_rather_than_re_derived() -> void:
	# **THE CLIENT IS TOLD WHAT IT WAS PAID.** A client re-deriving the final phase
	# from the tick would need the rule, the tuning and the same boundary, and would
	# disagree with the server at exactly the tick that matters.
	var rules: MatchTuning = Tuning.match_rules
	var late := int((rules.duration - rules.finalphase_duration) * rules.tick_rate) + 30
	var event := ScoreEvent.new(9, ScoreAward.new(late, Ids.SCORE_CONTRACT, 7, 8, 100.0), rules, 1)
	assert_almost_eq(event.multiplier, rules.finalphase_mult, 0.001, "the fixture is not in phase")
	assert_eq(ScoreWire.unpack(ScoreWire.pack(event, 1, 2)).points, event.points())


func test_a_truncated_row_is_refused() -> void:
	# `StreamPeerBuffer` answers a read past the end with zero, so an unpack that
	# did not check would turn a short packet into `SCORE-CONTRACT` for 0 points —
	# a feed line the server never sent.
	assert_null(ScoreWire.unpack(PackedByteArray()))
	assert_null(ScoreWire.unpack(ScoreWire.pack(_event(Ids.SCORE_STUN, 100.0), 1, 2).slice(0, 9)))


func test_an_unknown_id_packs_as_unknown_and_unpacks_as_nothing() -> void:
	assert_eq(ScoreKinds.to_byte(&"SCORE-NONESUCH"), ScoreKinds.UNKNOWN)
	assert_eq(ScoreKinds.from_byte(ScoreKinds.UNKNOWN), &"")


func test_unknown_is_not_the_first_row() -> void:
	# 255 rather than 0, because 0 is `SCORE-CONTRACT` — the commonest event in the
	# game and the worst thing for an undecodable byte to become.
	assert_ne(ScoreKinds.UNKNOWN, 0)
	assert_eq(ScoreKinds.ALL[0], Ids.SCORE_CONTRACT)
