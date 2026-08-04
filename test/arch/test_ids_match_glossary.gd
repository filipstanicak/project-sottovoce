## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## `Ids` and the docs corpus agree, IN BOTH DIRECTIONS.
##
## Why review misses this: both files are individually plausible. A constant
## nobody documented reads like ordinary code, and a documented ID nobody
## implemented reads like ordinary prose. Only the comparison shows the gap, and
## nothing at runtime ever performs it.
extends GutTest


func test_every_constant_is_documented() -> void:
	# An ID in code but not in the corpus is undocumented — it has a name and no
	# definition, so nobody can tell whether a second one would mean the same.
	var corpus: Dictionary = IdScanner.ids_in_corpus()
	var known: Dictionary = {}
	for ns: String in IdScanner.MIRRORED:
		for id: String in corpus[ns]:
			known[id] = true

	var undocumented: PackedStringArray = []
	for name: String in IdScanner.id_constants():
		var value := String(IdScanner.id_constants()[name])
		if not known.has(value):
			undocumented.append("%s = %s" % [name, value])
	undocumented.sort()

	assert_eq(
		undocumented.size(),
		0,
		(
			"Ids declares an ID that appears nowhere in docs/.\n"
			+ "Document it, or delete it before it is merged and becomes immutable.\n"
			+ "\n".join(undocumented)
		)
	)


func test_every_documented_id_is_declared() -> void:
	# An ID in the corpus but not in code is a name nobody implemented. That is
	# the more dangerous direction: the doc reads as though the thing exists.
	var corpus: Dictionary = IdScanner.ids_in_corpus()
	var declared: Dictionary = {}
	for name: String in IdScanner.id_constants():
		declared[String(IdScanner.id_constants()[name])] = true

	var missing: PackedStringArray = []
	for ns: String in IdScanner.MIRRORED:
		for id: String in corpus[ns]:
			if not declared.has(id) and not IdScanner.NOT_A_MEMBER.has(id):
				missing.append(id)
	missing.sort()

	assert_eq(
		missing.size(),
		0,
		(
			"The corpus names an ID that Ids does not declare.\n"
			+ "Add it to scripts/core/ids.gd, or — if it is not a runtime member of\n"
			+ "its namespace — add it to IdScanner.NOT_A_MEMBER *with a reason*.\n"
			+ "\n".join(missing)
		)
	)


func test_exclusions_are_still_real() -> void:
	# An exclusion that no longer corresponds to anything in the corpus is a
	# permanent hole nobody is watching. Same rule as the asset inventory: a
	# stale row is as much a defect as a missing one.
	var corpus: Dictionary = IdScanner.ids_in_corpus()
	var present: Dictionary = {}
	for ns: String in IdScanner.GRAMMAR:
		for id: String in corpus[ns]:
			present[id] = true

	var stale: PackedStringArray = []
	for id: String in IdScanner.NOT_A_MEMBER:
		if not present.has(id):
			stale.append(id)

	assert_eq(
		stale.size(),
		0,
		(
			"IdScanner.NOT_A_MEMBER excuses an ID the corpus no longer mentions.\n"
			+ "Delete the entry — an unwatched exclusion is how a guard rots.\n"
			+ "\n".join(stale)
		)
	)
