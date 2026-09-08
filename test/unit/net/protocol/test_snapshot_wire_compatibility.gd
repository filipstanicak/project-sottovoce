## Frozen from the pre-split encoder at 81f38d4. Never regenerate from the new codec.
## A symmetric writer/reader reorder passes a round trip but fails these exact bytes.
extends GutTest

const FIXTURE = preload("res://test/unit/net/protocol/snapshot_wire_fixture.gd")

const EMPTY := (
	"00000000000000000000000000000000000000000000000000000000000000000100000000000000"
	+ "0000000000000000000000000100000000"
)

const FULL := (
	"785634124523a50900004441000060c00080c542000010c00000003e00009040058403015715b004"
	+ "ffffa616c7c82c800103201c0212020270175e0150fb4003860557feaf005203e00f4502001170fe"
	+ "461e4680b4596504fef70fc047"
)

const LIMITS := (
	"785634124523a5ff00004441000060c00080c542000010c00000003e00009040ff8403005715b004"
	+ "ffffa500ffc82c800003201c021201010080ff7f000000ffff0100ffff7f0080ff00ff"
)


func test_encoding_matches_the_pre_split_bytes() -> void:
	var cases := [Snapshot.new(), FIXTURE.full(), FIXTURE.limits()]
	var expected := [EMPTY, FULL, LIMITS]
	for i: int in cases.size():
		assert_eq(cases[i].serialise().hex_encode(), expected[i])


func test_static_decode_reads_the_frozen_bytes() -> void:
	for hex_bytes: String in [EMPTY, FULL, LIMITS]:
		var snap := Snapshot.deserialise(hex_bytes.hex_decode())
		assert_not_null(snap)
		if snap != null:
			assert_eq(snap.serialise().hex_encode(), hex_bytes)
	var full := Snapshot.deserialise(FULL.hex_decode())
	assert_eq(full.hunt_fraction, 22)
	assert_eq(full.hunted_fraction, 199)
	assert_eq(full.remote_pawns[1][3], PawnStateId.LUNGING)
	assert_eq(full.npcs[0][3], 5)
	assert_eq(full.npcs[0][4], 20)


func test_deserialise_remains_static() -> void:
	var found := false
	for method: Dictionary in Snapshot.new().get_method_list():
		if method["name"] == "deserialise":
			found = true
			assert_ne(int(method["flags"]) & METHOD_FLAG_STATIC, 0)
	assert_true(found)
