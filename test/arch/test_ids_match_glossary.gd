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


## **THE CODEGEN CARRIES A COPY OF THE EXEMPTION TABLE, AND A COPY DRIFTS.**
## `tools/tuning_codegen/gen_ids.py` cannot read `IdScanner`, so it mirrors
## `NOT_A_MEMBER` as a Python set — and after #225 exempted `ANIM-CINDERFALL-CAST`
## here, the next `run_all.py` declared it in `ids.gd` anyway, because nothing held
## the two sets together. Found 2026-09-15 by regenerating for ADR-0020.
func test_the_codegen_mirror_of_the_exemptions_is_current() -> void:
	var source := FileAccess.get_file_as_string("res://tools/tuning_codegen/gen_ids.py")
	assert_false(source.is_empty(), "gen_ids.py could not be read")
	var regex := RegEx.new()
	regex.compile("(?m)^NOT_A_MEMBER\\s*=\\s*\\{([^}]*)\\}")
	var found := regex.search(source)
	assert_not_null(found, "gen_ids.py no longer declares NOT_A_MEMBER as a set literal")
	if found == null:
		return
	var mirrored: Dictionary = {}
	for piece: String in found.get_string(1).split(","):
		var id := piece.strip_edges().trim_prefix('"').trim_suffix('"')
		if not id.is_empty():
			mirrored[id] = true
	var here: Dictionary = {}
	for id: String in IdScanner.NOT_A_MEMBER:
		here[id] = true
	assert_eq(
		mirrored,
		here,
		(
			"gen_ids.py's NOT_A_MEMBER is not IdScanner.NOT_A_MEMBER. The Python set is a\n"
			+ "mirror; edit it in the same change, or run_all.py will declare an id the\n"
			+ "guard refuses."
		)
	)
