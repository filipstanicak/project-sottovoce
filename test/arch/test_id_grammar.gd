## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Every ID in the corpus and in `Ids` matches its namespace's regex from
## docs/30_bible/NAMING_AND_IDS.md §1.
##
## Why review misses this: a malformed ID reads perfectly. `MAT-GREY-FLOOR` and
## `MAT-STONE` both look like material IDs, and only the grammar says one of
## them broke the namespace's shape. By the time anyone notices, the ID is
## merged — and merged IDs are immutable, so the cheap fix is already gone.
extends GutTest


func test_every_corpus_id_matches_its_grammar() -> void:
	var corpus: Dictionary = IdScanner.ids_in_corpus()
	var violations: PackedStringArray = []
	for ns: String in IdScanner.GRAMMAR:
		var re := RegEx.create_from_string(IdScanner.GRAMMAR[ns])
		for id: String in corpus[ns]:
			if re.search(id) == null:
				violations.append("%s violates %s" % [id, IdScanner.GRAMMAR[ns]])
	violations.sort()

	assert_eq(
		violations.size(),
		0,
		(
			"An ID in docs/ does not match its namespace grammar.\n"
			+ "IDs are immutable once merged, so fix this BEFORE it lands:\n"
			+ "either correct the ID, or widen the grammar in NAMING_AND_IDS.md §1.\n"
			+ "\n".join(violations)
		)
	)


func test_every_declared_id_matches_its_grammar() -> void:
	var violations: PackedStringArray = []
	for name: String in IdScanner.id_constants():
		var value := String(IdScanner.id_constants()[name])
		var ns := value.split("-")[0]
		if not IdScanner.GRAMMAR.has(ns):
			violations.append("%s = %s — unknown namespace '%s'" % [name, value, ns])
			continue
		var re := RegEx.create_from_string(IdScanner.GRAMMAR[ns])
		if re.search(value) == null:
			violations.append("%s = %s violates %s" % [name, value, IdScanner.GRAMMAR[ns]])
	violations.sort()

	assert_eq(
		violations.size(),
		0,
		"An Ids constant does not match its namespace grammar.\n" + "\n".join(violations)
	)


func test_constant_name_is_derived_from_the_id() -> void:
	# The constant name must be the ID with hyphens as underscores, and nothing
	# else. A constant whose name drifts from its value is unsearchable: someone
	# greps the ID, finds the docs, and never finds the code.
	var wrong: PackedStringArray = []
	for name: String in IdScanner.id_constants():
		var value := String(IdScanner.id_constants()[name])
		var expected := value.replace("-", "_")
		if name != expected:
			wrong.append("%s should be named %s" % [name, expected])
	wrong.sort()

	assert_eq(wrong.size(), 0, "An Ids constant name does not match its ID.\n" + "\n".join(wrong))


func test_grammar_table_matches_the_bible() -> void:
	# IdScanner.GRAMMAR is a copy of NAMING_AND_IDS.md §1. A copy drifts, so the
	# copy is checked against the original rather than trusted.
	# A `|` inside a Markdown table cell must be written `\|`, so unescape before
	# comparing — otherwise the NET- alternation never matches its own source.
	var doc := FileAccess.get_file_as_string("res://docs/30_bible/NAMING_AND_IDS.md")
	doc = doc.replace("\\|", "|")
	var missing: PackedStringArray = []
	for ns: String in IdScanner.GRAMMAR:
		if not doc.contains("`" + IdScanner.GRAMMAR[ns] + "`"):
			missing.append("%s: %s" % [ns, IdScanner.GRAMMAR[ns]])
	missing.sort()

	assert_eq(
		missing.size(),
		0,
		(
			"IdScanner.GRAMMAR has drifted from NAMING_AND_IDS.md §1.\n"
			+ "The document is the authority; update the table to match it.\n"
			+ "\n".join(missing)
		)
	)
