## **THE KILLER MUST FACE THE VICTIM; THE VICTIM'S FACING IS IRRELEVANT.**
## US-0060, ASM-0010, TUNABLES §5.
##
## Killing somebody facing away from you is the **intended patient play**, not an
## exploit, and it is the payoff the whole approach phase is built for. A rule
## that quietly required the victim to be looking your way would delete it — and
## would look, from the code, exactly like a symmetry somebody tidied in.
##
## So the rule is enforced by an **absence**: `KillRules` never asks for the
## victim's yaw. The last test in this file scans the file for it, because a
## behavioural test alone would pass a rule that read the yaw and happened to
## ignore it.
extends GutTest

const KILLER := 21
const VICTIM := 22

var _t: CombatTuning


func before_each() -> void:
	_t = Tuning.combat


func _at(bearing_degrees: float, metres: float) -> Vector3:
	var radians := deg_to_rad(bearing_degrees)
	return Vector3(sin(radians), 0.0, cos(radians)) * metres


func _resolve(killer_yaw: float, victim_at: Vector3, victim_yaw: float) -> KillVerdict.V:
	var world := RewoundWorld.new()
	world.add(KILLER, Vector3.ZERO, killer_yaw)
	world.add(VICTIM, victim_at, victim_yaw)
	return KillRules.resolve(world, KILLER, VICTIM, PackedInt32Array([VICTIM]), _t)[0]


func test_the_victims_facing_changes_nothing_at_all() -> void:
	# Eight headings for the victim, the same kill each time. **This is ASM-0010**,
	# and it is the assertion that would go red if somebody made the cone mutual.
	var verdicts: Array[int] = []
	for heading: int in 8:
		verdicts.append(_resolve(0.0, _at(0.0, 2.0), deg_to_rad(heading * 45.0)))
	for verdict: int in verdicts:
		assert_eq(verdict, KillVerdict.V.ALLOWED, "the victim's facing decided a kill")


func test_the_classic_case_is_from_directly_behind() -> void:
	# The victim facing exactly away — 180 degrees from the killer's heading — is
	# the patient approach's payoff and must be the easiest kill in the game, not a
	# special case in the rule.
	assert_eq(_resolve(0.0, _at(0.0, 2.0), PI), KillVerdict.V.ALLOWED)


func test_the_cone_is_the_total_width_not_the_half() -> void:
	# `TUN-KILL-FACING-CONE` 60 degrees means +/- 30. Read as a half-width it would
	# be twice as forgiving — you could kill somebody standing beside you — and
	# every other assertion in this file would still pass.
	var half := _t.kill_facing_cone * 0.5
	assert_eq(
		_resolve(0.0, _at(half - 2.0, 2.0), 0.0),
		KillVerdict.V.ALLOWED,
		"a victim inside the cone was refused"
	)
	assert_eq(
		_resolve(0.0, _at(half + 2.0, 2.0), 0.0),
		KillVerdict.V.OUT_OF_CONE,
		"a victim outside the cone was killed — the cone is being read as a half-width"
	)


func test_the_cone_follows_the_killers_yaw_rather_than_a_world_axis() -> void:
	# The same relative geometry at four headings. A cone written against +Z would
	# pass at yaw 0 and fail at the other three — which is US-0092's defect, where
	# `LocomotionState` spent the stick on fixed world axes and survived nine
	# stories because every test asked whether the pawn moved rather than where.
	for heading: int in 4:
		var yaw := deg_to_rad(heading * 90.0)
		var ahead := Vector3(sin(yaw), 0.0, cos(yaw)) * 2.0
		assert_eq(
			_resolve(yaw, ahead, 0.0),
			KillVerdict.V.ALLOWED,
			"a kill straight ahead failed at yaw %d degrees" % (heading * 90)
		)


func test_the_cone_is_horizontal() -> void:
	# A victim directly above or below is not "in front of" you. Measuring the
	# angle in three dimensions would make a balcony a firing arc.
	var below := Vector3(0.0, -1.5, 1.0)
	assert_true(
		KillRules.within_cone(Vector3.ZERO, 0.0, below, _t),
		"the cone rejected somebody straight ahead and one metre down"
	)


func test_nothing_in_the_rules_reads_the_victims_yaw() -> void:
	# **THE STRUCTURAL HALF.** A rule enforced by a comment does not survive a
	# refactor; a rule enforced by there being no call does.
	#
	# `KillRules` calls `yaw_of` exactly once, for the KILLER, inside `resolve`.
	# Any second call is either the victim's yaw or a copy of the killer's, and
	# both are worth stopping.
	var code := SourceScanner.code_lines("res://scripts/core/combat/kill_rules.gd")
	var reads: PackedStringArray = []
	for row: Array in code:
		var line := String(row[1])
		if line.contains("yaw_of("):
			reads.append("line %d: %s" % [int(row[0]), line.strip_edges()])
	assert_eq(
		reads.size(),
		1,
		(
			"KillRules reads a yaw more than once — ASM-0010 says the victim's facing is\n"
			+ "irrelevant, and the way that stays true is that there is nowhere to read it.\n"
			+ "\n".join(reads)
		)
	)
	assert_true(reads[0].contains("killer"), "the single yaw read is not the killer's")
