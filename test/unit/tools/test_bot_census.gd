## **THE INSTRUMENT THAT CHECKS THE PARITY CLAIM, CHECKED ITSELF.** US-0102.
##
## This corpus has paid seven times for an instrument wrong in a plausible direction,
## so each of the four numbers is held to a synthetic track whose answer is known.
extends GutTest

const CENSUS := preload("res://tools/bot_census.gd")


## A straight walk at `speed` for `seconds`, sampled every 0.2 s from `t0`.
func _walk(
	census: RefCounted, key: String, t0: float, from: Vector3, speed: float, seconds: float
) -> Vector3:
	var at := from
	var t := t0
	while t < t0 + seconds:
		census.add(key, t, at)
		at += Vector3(0.0, 0.0, speed * 0.2)
		t += 0.2
	return at


func test_a_steady_walk_reads_its_own_speed() -> void:
	var census: RefCounted = CENSUS.new()
	_walk(census, "a", 0.0, Vector3.ZERO, 1.4, 10.0)
	var s: Dictionary = census.summary(["a"])
	assert_almost_eq(float(s["moving_speed"]), 1.4, 0.01, "a 1.4 m/s walk read otherwise")
	assert_almost_eq(float(s["standing_share"]), 0.0, 0.01, "a walker was counted as standing")
	assert_almost_eq(float(s["turn_rate"]), 0.0, 0.01, "a straight line was counted as turning")


func test_a_stop_is_measured_by_its_length_and_its_share() -> void:
	var census: RefCounted = CENSUS.new()
	var at := _walk(census, "a", 0.0, Vector3.ZERO, 1.4, 10.0)
	var t := 10.0
	while t < 15.0:
		census.add("a", t, at)
		t += 0.2
	_walk(census, "a", 15.0, at, 1.4, 10.0)
	var s: Dictionary = census.summary(["a"])
	assert_almost_eq(float(s["mean_stop"]), 5.0, 0.3, "a five-second stop read otherwise")
	assert_almost_eq(float(s["standing_share"]), 0.2, 0.03, "a fifth of the time standing")


## **A FIGURE THAT LEFT THE VIEW AND CAME BACK DID NOT SPRINT.** NPCs cross the cull
## radius whenever the observer walks; the jump across the gap is not a walk.
func test_a_gap_is_not_read_as_speed() -> void:
	var census: RefCounted = CENSUS.new()
	_walk(census, "a", 0.0, Vector3.ZERO, 1.4, 5.0)
	_walk(census, "a", 8.0, Vector3(0.0, 0.0, 60.0), 1.4, 5.0)
	var s: Dictionary = census.summary(["a"])
	assert_almost_eq(float(s["moving_speed"]), 1.4, 0.01, "the gap was read as a sprint")


func test_a_zigzag_turns_more_than_a_straight_line() -> void:
	var census: RefCounted = CENSUS.new()
	var at := Vector3.ZERO
	for i: int in 50:
		census.add("zig", i * 0.2, at)
		at += Vector3(0.28 if i % 2 == 0 else -0.28, 0.0, 0.1)
	_walk(census, "line", 0.0, Vector3.ZERO, 1.4, 10.0)
	var zig: Dictionary = census.summary(["zig"])
	var line: Dictionary = census.summary(["line"])
	assert_gt(float(zig["turn_rate"]), float(line["turn_rate"]) + 1.0, "zigzag read as straight")


func test_groups_are_kept_apart_by_prefix() -> void:
	var census: RefCounted = CENSUS.new()
	_walk(census, "npc:1", 0.0, Vector3.ZERO, 1.4, 5.0)
	_walk(census, "npc:2", 0.0, Vector3.ONE, 1.4, 5.0)
	_walk(census, "player:1", 0.0, Vector3.ZERO, 2.2, 5.0)
	assert_eq(census.keys_with_prefix("npc:").size(), 2, "the crowd group is wrong")
	var players: Dictionary = census.summary(census.keys_with_prefix("player:"))
	assert_almost_eq(float(players["moving_speed"]), 2.2, 0.01, "players read the crowd's speed")
