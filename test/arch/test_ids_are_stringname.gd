## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Every `Ids` constant is a `StringName`, never a `String`.
##
## Why review misses this: `"SCORE-BLENDED"` and `&"SCORE-BLENDED"` differ by one
## character and behave identically in every test. The difference is that
## `StringName` compares pointer-equal and allocates nothing, while `String`
## compares character-by-character and allocates on every construction. These IDs
## sit on the hot path — every score append, every ability lookup, every state
## transition — so a missing `&` is a performance regression that no assertion
## about behaviour will ever catch.
extends GutTest


func test_no_constant_is_a_plain_string() -> void:
	var wrong: PackedStringArray = []
	var constants: Dictionary = IdScanner.id_constants()
	for name: String in constants:
		if typeof(constants[name]) != TYPE_STRING_NAME:
			wrong.append(
				"%s is %s, expected StringName" % [name, type_string(typeof(constants[name]))]
			)
	wrong.sort()

	assert_eq(
		wrong.size(),
		0,
		'An Ids constant is not a StringName. Write &"ID", not "ID".\n' + "\n".join(wrong)
	)


func test_ids_declares_a_meaningful_number_of_constants() -> void:
	# Guards the guard. If `Ids` were ever emptied or failed to load, every
	# assertion above would pass over an empty dictionary and report success.
	assert_gt(
		IdScanner.id_constants().size(),
		100,
		"Ids has almost no constants — did it fail to load, or get truncated?"
	)
