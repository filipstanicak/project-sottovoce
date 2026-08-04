## `compute_hash()` is stable over VALUES only.
##
## TEL-MATCH-START records the tuning hash so archived telemetry stays
## interpretable: a match played under different numbers must be identifiable as
## such. That only works if the hash depends on the numbers and nothing else —
## not the file path, not the load order, not the resource name.
extends GutTest

const PROFILE := "res://data/tuning/default/profile.tres"


func test_two_loads_of_the_same_values_hash_identically() -> void:
	var a: TuningProfile = load(PROFILE).duplicate(true)
	var b: TuningProfile = load(PROFILE).duplicate(true)
	assert_eq(a.compute_hash(), b.compute_hash(), "identical values must hash identically")


func test_the_hash_ignores_resource_path_and_name() -> void:
	var a: TuningProfile = load(PROFILE).duplicate(true)
	var b: TuningProfile = load(PROFILE).duplicate(true)
	b.resource_name = "a different name"
	b.resource_path = ""
	assert_eq(
		a.compute_hash(),
		b.compute_hash(),
		"the hash must depend on values only — metadata changed it"
	)


func test_changing_any_value_changes_the_hash() -> void:
	var a: TuningProfile = load(PROFILE).duplicate(true)
	var before := a.compute_hash()
	a.movement.sprint += 0.1
	assert_ne(before, a.compute_hash(), "a changed value must change the hash")


func test_a_change_in_a_different_section_also_changes_it() -> void:
	# Every section must contribute. A fingerprint that silently covered only the
	# first section would pass the test above and be worthless.
	var a: TuningProfile = load(PROFILE).duplicate(true)
	var before := a.compute_hash()
	a.scoring.blended += 1.0
	assert_ne(before, a.compute_hash(), "scoring changes must reach the hash too")
