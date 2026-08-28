## **AIM IS CLAMPED, NEVER REJECTED.** TDD-09 §1.1, US-0066.
##
## The story's own note gives the reason in one sentence: *clamping rather than
## rejecting means a rounding difference between predicted and server aim produces
## the outcome the player intended rather than a denial.*
##
## **THE DIFFERENCE IS THERE ON EVERY CAST, NOT OCCASIONALLY.** The client predicts
## its own position and leads the server by two commands; the look angle arrives
## quantised to a byte; the physics tick boundary falls where it falls. A player
## aiming at exactly 8.0 m has already sent 8.03 by the time the packet lands, and
## refusing on that would deny a cast they had every reason to believe in.
extends GutTest

const REACH := 8.0

var _facing := Vector3(0.0, 0.0, 1.0)


func _aim(direction: Vector3, reach: float = REACH) -> AimData:
	return AbilityRules.aim(Vector3.ZERO, direction, _facing, reach)


func test_an_aim_inside_the_reach_is_left_alone() -> void:
	# **THE PREMISE.** A clamp that always clamped would satisfy every assertion
	# below about the far end and would quietly delete aiming.
	var data := _aim(Vector3(0.0, 0.0, 5.0))
	assert_almost_eq(data.point.z, 5.0, 0.0001, "an aim well inside the reach was moved")
	assert_false(data.clamped, "an aim inside the reach was reported as clamped")


func test_an_aim_past_the_reach_lands_at_the_reach() -> void:
	var data := _aim(Vector3(0.0, 0.0, 40.0))
	assert_almost_eq(data.point.z, REACH, 0.0001, "the aim was not clamped to the reach")
	assert_true(data.clamped, "the clamp was not recorded")


func test_a_rounding_error_past_the_line_is_not_a_denial() -> void:
	# The case the rule exists for: three centimetres past 8 m.
	var data := _aim(Vector3(0.0, 0.0, REACH + 0.03))
	assert_almost_eq(data.point.z, REACH, 0.0001)
	assert_almost_eq(data.direction.z, 1.0, 0.0001, "the direction survived the clamp")


func test_the_direction_is_always_unit_length() -> void:
	# **NORMALISED HERE AND NOWHERE ELSE.** Four effects each writing their own
	# guard is four chances for one of them to forget.
	for direction: Vector3 in [
		Vector3(0.0, 0.0, 40.0), Vector3(3.0, 4.0, 0.0), Vector3(0.0, 0.0, 0.2)
	]:
		assert_almost_eq(_aim(direction).direction.length(), 1.0, 0.0001, "%s" % direction)


func test_a_zero_direction_falls_back_to_the_facing() -> void:
	# A client can send anything. The least surprising thing a mis-sent cast can do
	# is go where the player was looking.
	var data := _aim(Vector3.ZERO)
	assert_almost_eq(data.direction.z, 1.0, 0.0001, "a zero aim did not fall back to the facing")
	assert_almost_eq(data.point.length(), 0.0, 0.0001, "a zero-length aim reached somewhere")


func test_a_nonsense_direction_falls_back_rather_than_propagating() -> void:
	# **NaN IS THE ONE THAT WOULD SPREAD.** A NaN point reaches an effect, then a
	# position, then a snapshot — and the symptom is a player teleporting to
	# nowhere, three systems away from the cast that caused it.
	var data := _aim(Vector3(NAN, NAN, NAN))
	assert_true(data.direction.is_finite(), "a NaN aim produced a NaN direction")
	assert_true(data.point.is_finite(), "a NaN aim produced a NaN point")


func test_an_ability_with_no_reach_aims_at_its_own_origin() -> void:
	# Second Face acts on the self and reaches nowhere. The clamp must produce the
	# caster's own position rather than a division or a fallback distance.
	var data := _aim(Vector3(0.0, 0.0, 12.0), 0.0)
	assert_almost_eq(data.point.length(), 0.0, 0.0001, "a self-cast reached somewhere")
	assert_true(data.clamped, "a self-cast aimed 12 m away was not recorded as clamped")


func test_the_reach_comes_from_whichever_field_this_ability_populates() -> void:
	# **`AbilityData` IS ONE CLASS HOLDING FOUR ABILITIES' FIELDS**, so each `.tres`
	# populates only its own and the non-zero one is that ability's reach. Asserted
	# against the shipped data rather than against the rule, because the rule is
	# only true while that convention holds.
	var cinderfall: AbilityData = Tuning.ability_data(Ids.ABIL_CINDERFALL)
	var lunge: AbilityData = Tuning.ability_data(Ids.ABIL_LUNGE)
	assert_not_null(cinderfall, "the shipped profile has no Cinderfall")
	assert_not_null(lunge, "the shipped profile has no Lunge")
	assert_eq(AbilityRules.reach_of(cinderfall), cinderfall.throw_range, "Cinderfall throws")
	assert_eq(AbilityRules.reach_of(lunge), lunge.distance, "Lunge dashes")
	assert_gt(AbilityRules.reach_of(cinderfall), 0.0, "Cinderfall reaches nowhere")
	assert_gt(AbilityRules.reach_of(lunge), 0.0, "Lunge reaches nowhere")


func test_a_missing_ability_reaches_nowhere_rather_than_erroring() -> void:
	assert_eq(AbilityRules.reach_of(null), 0.0)
