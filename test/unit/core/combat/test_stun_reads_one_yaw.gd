## **THE STUNNER MUST FACE THE PURSUER; THE PURSUER'S FACING IS IRRELEVANT.**
## US-0061, GDD-03 §10.
##
## Stunning somebody who is looking away from you is fine, and it is what a prey
## who spotted a marker and doubled back is *supposed* to do. A rule that quietly
## required the hunter to be facing you would delete that play — and would look,
## from the code, exactly like a symmetry somebody tidied in.
##
## The rule is enforced by an **absence**: `StunRules` never asks for the
## pursuer's yaw. The last test scans the file, because a behavioural test alone
## would pass a rule that read the yaw and happened to ignore it — which is
## `test_kill_facing_cone.gd`'s finding, applied to the other verb.
extends GutTest

const STUNNER := 31
const PURSUER := 32

var _t: CombatTuning


func before_each() -> void:
	_t = Tuning.combat


func _at(bearing_degrees: float, metres: float) -> Vector3:
	var radians := deg_to_rad(bearing_degrees)
	return Vector3(sin(radians), 0.0, cos(radians)) * metres


func _resolve(stunner_yaw: float, pursuer_at: Vector3, pursuer_yaw: float) -> StunVerdict.V:
	var world := RewoundWorld.new()
	world.add(STUNNER, Vector3.ZERO, stunner_yaw)
	world.add(PURSUER, pursuer_at, pursuer_yaw)
	return StunRules.resolve(world, STUNNER, PURSUER, PackedInt32Array([PURSUER]), _t)[0]


func test_the_pursuers_facing_changes_nothing() -> void:
	var verdicts: Array[int] = []
	for heading: int in range(0, 360, 45):
		verdicts.append(_resolve(0.0, _at(0.0, 2.0), deg_to_rad(float(heading))))
	for verdict: int in verdicts:
		assert_eq(
			verdict, StunVerdict.V.ALLOWED, "a stun depended on which way the pursuer was looking"
		)


func test_the_cone_is_a_total_width_and_not_a_half_width() -> void:
	# Read as a half-width the cone would be twice as forgiving — 240° rather than
	# 120° — and a prey could stun somebody standing almost directly behind them.
	var half := _t.stun_facing_cone * 0.5
	assert_eq(_resolve(0.0, _at(half - 1.0, 2.0), 0.0), StunVerdict.V.ALLOWED, "inside the cone")
	assert_eq(
		_resolve(0.0, _at(half + 1.0, 2.0), 0.0),
		StunVerdict.V.OUT_OF_CONE,
		"a pursuer past half of TUN-STUN-FACING-CONE was still stunnable"
	)


func test_directly_behind_is_out_of_cone() -> void:
	assert_eq(
		_resolve(0.0, _at(180.0, 2.0), 0.0),
		StunVerdict.V.OUT_OF_CONE,
		"a pursuer directly behind the prey was stunnable — the prey never turned round"
	)


func test_a_pursuer_missing_from_the_rewound_world_is_not_a_target() -> void:
	var world := RewoundWorld.new()
	world.add(STUNNER, Vector3.ZERO, 0.0)
	var verdict: StunVerdict.V = (
		StunRules.resolve(world, STUNNER, PURSUER, PackedInt32Array([PURSUER]), _t)[0]
	)
	assert_eq(verdict, StunVerdict.V.NO_TARGET, "a pursuer the ring never held was stunned")


func test_a_stunner_missing_from_the_rewound_world_costs_nothing() -> void:
	# The ring did not hold them. Not a mistake the player made, so the safe answer
	# is the one that charges nothing — `BUSY` rather than a penalised verdict.
	var world := RewoundWorld.new()
	world.add(PURSUER, Vector3(0.0, 0.0, 2.0), 0.0)
	var verdict: StunVerdict.V = (
		StunRules.resolve(world, STUNNER, PURSUER, PackedInt32Array([PURSUER]), _t)[0]
	)
	assert_eq(verdict, StunVerdict.V.BUSY, "a stunner the ring lost was charged for it")
	assert_false(StunVerdict.costs_the_stunner(verdict), "BUSY became a penalised verdict")


func test_stun_rules_reads_a_yaw_exactly_once() -> void:
	# `StunRules` calls `yaw_of` once, for the STUNNER, inside `resolve`. Any second
	# call is either the pursuer's yaw or a copy of the stunner's, and both are
	# worth stopping.
	var code := SourceScanner.code_lines("res://scripts/core/combat/stun_rules.gd")
	var reads: PackedStringArray = []
	for row: Array in code:
		var line := String(row[1])
		if line.contains("yaw_of("):
			reads.append("line %d: %s" % [int(row[0]), line.strip_edges()])
	assert_eq(
		reads.size(),
		1,
		(
			"StunRules reads a yaw more than once — the pursuer's facing is irrelevant,\n"
			+ "and the way that stays true is that there is nowhere to read it.\n"
			+ "\n".join(reads)
		)
	)
	assert_true(reads[0].contains("stunner"), "the single yaw read is not the stunner's")
