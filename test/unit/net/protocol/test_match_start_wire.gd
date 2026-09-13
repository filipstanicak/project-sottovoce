## **`NET-S2C-MATCH-START`, AND THE SEED THAT MUST ARRIVE BIT-EXACT.** US-0079's
## last criterion.
##
## `CrowdRoster` gives every NPC its persona from `hash(match_seed)` on every peer
## alike, so one wrong bit is a client whose whole crowd wears different faces from
## the ones the server placed — and nothing on screen would say so, because every
## NPC still walks and still hides somebody. The sweep below is the values that break
## a careless encoder: zero, a playtest's `--seed`, and a seed with its top bit set,
## which a signed read turns negative.
extends GutTest

## Zero is `--seed 0` and is legal; the last is the top bit, which `get_64` would
## read as negative and `get_u64` must not.
const SEEDS := [0, 42, 20190020, 1 << 40, 1 << 63, -1]


func test_the_row_is_thirteen_bytes() -> void:
	# `match_seed:u64, start_tick:u32, crowd_count:u8` — the catalogue's own widths.
	assert_eq(MatchStartWire.pack(1, 2, 3).size(), MatchStartWire.SIZE)
	assert_eq(MatchStartWire.SIZE, 8 + 4 + 1)


func test_every_seed_survives_the_round_trip_bit_exact() -> void:
	for seed_value: int in SEEDS:
		var fields := MatchStartWire.unpack(MatchStartWire.pack(seed_value, 900, 78))
		assert_eq(fields.size(), 3, "seed %d did not unpack" % seed_value)
		assert_eq(
			int(fields[0]),
			seed_value,
			(
				"seed %d arrived as %d — one wrong bit is a whole crowd wearing the wrong faces"
				% [seed_value, int(fields[0])]
			)
		)
		assert_eq(int(fields[1]), 900)
		assert_eq(int(fields[2]), 78)


## **A SHORT PACKET IS DROPPED WHOLE**, `ScoreWire`'s rule. `StreamPeerBuffer`
## answers a read past the end with zero, and zero is a *legal* seed, so a
## truncated payload would not look wrong anywhere — it would dress the crowd.
func test_a_packet_of_the_wrong_size_is_refused_rather_than_read_as_zeros() -> void:
	var whole := MatchStartWire.pack(42, 900, 78)
	assert_eq(MatchStartWire.unpack(whole.slice(0, whole.size() - 1)), [])
	assert_eq(MatchStartWire.unpack(PackedByteArray()), [])
	var long := whole.duplicate()
	long.append(0)
	assert_eq(MatchStartWire.unpack(long), [])


## **THE BYTE IS HONEST TODAY AND THIS IS WHAT SAYS SO TOMORROW.** `crowd_count:u8`
## clamps at 255; `TUN-CROWD-COUNT-MAX` is 90. The day the cap outgrows the byte,
## the wire would report a smaller crowd than the server placed and nothing else
## in the project would notice — so the width is asserted against the tunable
## rather than assumed, which is `test_the_announced_multiplier_is_the_one_that_pays`'s
## shape for a second field.
func test_the_crowd_cap_still_fits_the_byte() -> void:
	assert_lte(
		Tuning.crowd.count_max,
		255,
		"TUN-CROWD-COUNT-MAX no longer fits crowd_count:u8; widen the row, do not clamp"
	)
