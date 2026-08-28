## **EVERY `SCORE-` ID HAS A WIRE BYTE AND A NAME A PLAYER CAN READ.** GDD-06 §3.2,
## US-0074.
##
## *"Named, not numeric — the name IS the lesson. A player who reads `Patient`
## three times learns the word, then the condition, then the behaviour."* So a
## bonus with no string is a bonus that teaches nothing, and the failure is silent:
## `Strings.get_text` returns the key on a miss, which is right everywhere else and
## reads as a bonus called `bonus.closecall` here.
##
## **THIS FOUND THREE ON ITS FIRST RUN.** `SCORE-HALFSEEN` was added on 2026-08-27
## by the fidelity re-audit and `SCORE-ESCAPE`/`SCORE-CLOSECALL` on 2026-08-26 by
## ADR-0014, and none of the three had a row in `data/strings/en.csv` — the table
## looked complete because it held fourteen of seventeen. Trap 14's family in a
## data file.
extends GutTest


## Every `SCORE-` id `Ids` declares, harvested from its source rather than listed,
## so a new id is covered by having been added at all.
##
## **HARVESTED FROM THE CONSTANT NAME, NOT ITS VALUE**, and that is not a
## preference: `SourceScanner.code_lines` blanks string literals so a guard is
## never tripped by its own documentation, so reading `&"SCORE-CONTRACT"` there
## returns an empty string. Deriving `SCORE-CONTRACT` from `SCORE_CONTRACT` asserts
## `NAMING_AND_IDS.md`'s own rule on the way past.
func _score_ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for line: String in SourceScanner.read("res://scripts/core/ids.gd").split("\n"):
		var text := line.strip_edges()
		if not text.begins_with("const SCORE_"):
			continue
		found.append(StringName(text.split(" ")[1].replace("_", "-")))
	return found


func test_the_harvest_found_the_ids_at_all() -> void:
	# The vacuous-success guard: an empty list satisfies every assertion below.
	assert_gt(_score_ids().size(), 12, "the harvest read no SCORE- ids out of Ids")


func test_every_id_is_on_the_wire_list() -> void:
	# A kind missing from `ScoreKinds.ALL` packs as `UNKNOWN` and the feed draws
	# nothing for a bonus the server paid — an award that vanishes between the log
	# and the player, with no error anywhere.
	for id: StringName in _score_ids():
		assert_has(ScoreKinds.ALL, id, "%s has no wire byte" % id)


func test_the_wire_list_holds_nothing_that_is_not_an_id() -> void:
	assert_eq(ScoreKinds.ALL.size(), _score_ids().size(), "ScoreKinds.ALL and Ids disagree")


func test_every_kind_has_a_display_name() -> void:
	for id: StringName in ScoreKinds.ALL:
		var key := ScoreKinds.string_key(id)
		assert_ne(key, &"", "%s produced no string key" % id)
		assert_true(Strings.has(key), "%s has no row in the string table (%s)" % [id, key])


func test_the_key_is_derived_rather_than_tabulated() -> void:
	# **A SECOND HAND-WRITTEN LIST WOULD BE SEVENTEEN CHANCES TO MISTYPE ONE.** The
	# derivation is the whole reason the test above can be written as a loop.
	assert_eq(ScoreKinds.string_key(Ids.SCORE_FROMABOVE), &"bonus.fromabove")
	assert_eq(ScoreKinds.string_key(Ids.SCORE_CLOSECALL), &"bonus.closecall")
	assert_eq(ScoreKinds.string_key(&"NOT-A-SCORE-ID"), &"")


func test_the_names_are_words_rather_than_keys() -> void:
	# The lesson is the word. A row whose value is its own key would pass the
	# existence test above and read as a broken string in front of a player.
	for id: StringName in ScoreKinds.ALL:
		var key := ScoreKinds.string_key(id)
		assert_ne(Strings.get_text(key), String(key), "%s displays as its own key" % id)
