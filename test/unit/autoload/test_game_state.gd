## **THE CLIENT'S COPY OF WHICH MATCH IT IS IN, AND THE ONE HOP THAT WRITES IT.**
## US-0079.
##
## `GameState` is a mirror with one writer, `scripts/net/`, and until 2026-09-13 it
## had two mutators and no test of its own — `replace` and `clear` were covered
## only through the handshake. `adopt_match` is the third, for
## `NET-S2C-MATCH-START`, and the hop that matters is the last test: the payload
## goes in at `SessionWire.s2c_match_start` and the fields come out here, which is
## the seam between the codec's test and this one that neither would see broken.
extends GutTest


func after_each() -> void:
	# The autoload outlives the test. A seed left here would dress the next
	# fixture's crowd, which is exactly what `clear()` exists to prevent in play.
	GameState.clear()


func test_a_fresh_state_knows_no_match() -> void:
	assert_false(GameState.has_match())
	assert_eq(GameState.match_seed, 0)


func test_adopting_a_match_sets_every_field_and_says_so() -> void:
	var told := [0]
	GameState.state_replaced.connect(func() -> void: told[0] += 1, CONNECT_ONE_SHOT)
	GameState.adopt_match(20190020, 450, 78)
	assert_true(GameState.has_match())
	assert_eq(GameState.match_seed, 20190020)
	assert_eq(GameState.start_tick, 450)
	assert_eq(GameState.crowd_count, 78)
	assert_eq(told[0], 1, "adopting a match did not announce a replaced state")


## **ZERO IS A LEGAL SEED**, which is why `has_match()` is a flag and not a test of
## the seed for truth: `--seed 0` must be distinguishable from *not told yet*.
func test_a_seed_of_zero_is_a_known_match() -> void:
	GameState.adopt_match(0, 0, 0)
	assert_true(GameState.has_match(), "a seed of zero read as no match at all")


func test_clearing_forgets_the_match_before_anybody_hears_about_it() -> void:
	GameState.adopt_match(42, 900, 78)
	var seen := [-1]
	GameState.state_replaced.connect(
		func() -> void: seen[0] = GameState.match_seed, CONNECT_ONE_SHOT
	)
	GameState.clear()
	assert_false(GameState.has_match())
	assert_eq(GameState.match_seed, 0)
	assert_eq(GameState.start_tick, 0)
	assert_eq(GameState.crowd_count, 0)
	assert_eq(seen[0], 0, "a listener to state_replaced read the old seed through clear()")


## **THE HOP.** The codec is proven in `test_match_start_wire.gd`; this drives the
## real handler on the real autoload, so a handler that unpacked and forgot to
## adopt would leave both files green and every client ignorant of its match.
func test_the_message_lands_in_game_state() -> void:
	var heard := []
	Net.session.match_started.connect(
		func(seed_value: int, began_at: int, crowd: int) -> void:
			heard.append([seed_value, began_at, crowd]),
		CONNECT_ONE_SHOT
	)
	Net.session.s2c_match_start(MatchStartWire.pack(20190020, 450, 78))
	assert_true(GameState.has_match(), "the message arrived and GameState was not told")
	assert_eq(GameState.match_seed, 20190020)
	assert_eq(GameState.start_tick, 450)
	assert_eq(GameState.crowd_count, 78)
	assert_eq(heard, [[20190020, 450, 78]], "the arrival was not announced on the wire node")


## A malformed payload must leave the state untouched: a seed of zero adopted
## from a truncated packet is a whole crowd wearing the wrong faces.
func test_a_malformed_payload_adopts_nothing() -> void:
	# The handler refuses LOUDLY, which is the point, and GUT counts a `push_error`
	# as a failure — so the log is raised over the one call rather than the
	# refusal being softened. `test_npc_pool.gd`'s shape.
	var was: Log.Level = Log.min_level
	Log.min_level = Log.Level.ERROR + 1 as Log.Level
	Net.session.s2c_match_start(PackedByteArray([1, 2, 3]))
	Log.min_level = was
	assert_false(GameState.has_match(), "a three-byte payload was adopted as a match")
