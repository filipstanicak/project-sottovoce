## **A BOT THAT WALKS THE CROWD'S WALK.** US-0102.
##
## Each test holds one of the parity claims in `bot_civilian.gd`'s table to the rule
## the crowd follows, through an injected path finder so no navigation server is
## needed: the brain's choices, not the district's geometry, are what is under test.
extends GutTest

const CIVILIAN := preload("res://tools/bot_civilian.gd")
const ANCHORS := [
	Vector3(0.0, 0.0, 20.0),
	Vector3(20.0, 0.0, 0.0),
	Vector3(-20.0, 0.0, 0.0),
	Vector3(0.0, 0.0, -20.0),
	Vector3(40.0, 0.0, 40.0),
]

var _asked: Array = []


## A straight path with one corner halfway, so corner-following is exercised too.
func _straight(from: Vector3, to: Vector3) -> PackedVector3Array:
	_asked.append(to)
	return PackedVector3Array([from, from.lerp(to, 0.5), to])


func _brain(seed_from: int = 1) -> RefCounted:
	_asked = []
	return CIVILIAN.new(seed_from, ANCHORS, _straight)


func _pawn(at: Vector3, yaw: float) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.position = at
	pawn.yaw = yaw
	return pawn


## The corner the brain is steering for, at the given bearing, `distance` ahead.
func _facing(brain: RefCounted, off: float) -> Array:
	brain.decide(_pawn(Vector3.ZERO, 0.0))
	var goal: Vector3 = brain.target()
	var bearing := CompassMath.bearing_to(Vector3.ZERO, goal)
	return brain.decide(_pawn(Vector3.ZERO, bearing - off))


func test_a_stroll_goes_to_an_idle_anchor() -> void:
	var brain := _brain()
	brain.decide(_pawn(Vector3.ZERO, 0.0))
	assert_true(ANCHORS.has(brain.target()), "the bot walked somewhere no NPC would")
	assert_eq(_asked.size(), 1, "the way there was not asked of the navmesh")


## **BLEND-WALK, WHICH IS THE CROWD'S SPEED** (invariant 1). Plain forward is
## `TUN-SPEED-STROLL` 2.2 m/s against the crowd's 1.4 — a figure 57 % faster than
## every NPC around it.
func test_it_walks_at_the_crowds_speed() -> void:
	var keys: Array = _facing(_brain(), 0.0)[0]
	assert_true(keys.has("input_move_forward"), "facing the corner, the bot did not walk")
	assert_true(keys.has("input_slow"), "the bot walked faster than the crowd")
	assert_false(keys.has("input_run"), "the bot ran")


func test_a_corner_to_the_left_is_turned_toward_while_walking() -> void:
	var keys: Array = _facing(_brain(), 0.5)[0]
	assert_true(keys.has("input_look_left"), "a corner to the left was not turned toward")
	assert_true(keys.has("input_move_forward"), "a gentle turn stopped the walk")


func test_a_corner_behind_is_turned_toward_in_place() -> void:
	var keys: Array = _facing(_brain(), -2.0)[0]
	assert_true(keys.has("input_look_right"), "a corner behind to the right was not turned to")
	assert_false(keys.has("input_move_forward"), "the bot walked an arc into the wall")


## **ARRIVAL IS A STOP OF AN NPC'S LENGTH**, `NpcBrain._enter`'s draw over the same two
## tunables. A bot that paused for a second and walked on was the third tell.
func test_arrival_stands_for_an_npcs_idle() -> void:
	var brain := _brain()
	brain.decide(_pawn(Vector3.ZERO, 0.0))
	var goal: Vector3 = brain.target()
	brain.decide(_pawn(goal, 0.0))
	assert_eq(brain.mode, CIVILIAN.Mode.IDLE, "reaching the anchor did not stop the bot")
	var stood := 0.0
	var plan: Array = brain.decide(_pawn(goal, 0.0))
	# Until the next stroll *begins*, not until the mode changes: a bot that draws the
	# same anchor again arrives at once and stands again, and that is a second idle.
	while brain.strolls() == 1 and stood < 100.0:
		assert_eq((plan[0] as Array).size(), 0, "an idle bot held a key")
		stood += float(plan[1])
		plan = brain.decide(_pawn(goal, 0.0))
	assert_between(
		stood,
		Tuning.crowd.idle_duration_min,
		Tuning.crowd.idle_duration_max + CIVILIAN.IDLE_BEAT,
		"the bot stood a length no NPC stands"
	)
	assert_eq(brain.strolls(), 2, "after the idle the bot did not walk on")


## **UNIFORM OVER EVERY ANCHOR**, `CrowdIntent._an_anchor`'s rule. Nearest-first would
## keep a bot circling its own corner of the district.
func test_every_anchor_is_chosen_not_only_the_nearest() -> void:
	var counts: Dictionary = {}
	for seed_from: int in 200:
		var brain := _brain(seed_from)
		brain.decide(_pawn(Vector3.ZERO, 0.0))
		counts[brain.target()] = int(counts.get(brain.target(), 0)) + 1
	for anchor: Vector3 in ANCHORS:
		assert_gt(int(counts.get(anchor, 0)), 15, "%s was almost never chosen" % anchor)


## **A WEDGED BOT GIVES UP ON ITS ANCHOR**, measured by displacement, not predicted.
func test_a_bot_that_cannot_move_while_walking_finds_another_way() -> void:
	var brain := _brain()
	var stuck := _pawn(Vector3.ZERO, 0.0)
	brain.decide(stuck)
	stuck.yaw = CompassMath.bearing_to(Vector3.ZERO, brain.target())
	for _i: int in CIVILIAN.STUCK_BEATS + 2:
		brain.decide(stuck)
	assert_gt(brain.strolls(), 1, "a wedged bot pressed forward into the wall for ever")


## And turning in place is not being stuck: nothing moves, and nothing is wrong.
func test_turning_in_place_is_not_being_stuck() -> void:
	var brain := _brain()
	var turning := _pawn(Vector3.ZERO, 0.0)
	brain.decide(turning)
	turning.yaw = CompassMath.bearing_to(Vector3.ZERO, brain.target()) + PI
	for _i: int in CIVILIAN.STUCK_BEATS * 2:
		brain.decide(turning)
	assert_eq(brain.strolls(), 1, "a bot turning toward its corner was declared stuck")


func test_a_district_with_no_anchors_stands_rather_than_crashes() -> void:
	var brain: RefCounted = CIVILIAN.new(1, [], _straight)
	var plan: Array = brain.decide(_pawn(Vector3.ZERO, 0.0))
	assert_eq((plan[0] as Array).size(), 0, "a bot with nowhere to go held keys")
	assert_eq(brain.mode, CIVILIAN.Mode.IDLE, "a bot with nowhere to go kept strolling")
