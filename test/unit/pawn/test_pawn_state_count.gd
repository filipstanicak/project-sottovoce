## `PawnStateId.ALL` matches the normative state table in GDD-02 §3.1, name for
## name.
##
## Why this is worth its own file: the count was wrong in SIX places in the
## corpus while both normative sources said fifteen, and nothing noticed, because
## a prose number is not checkable. This makes it checkable — the list in code is
## compared against the table in the document, so the next time they diverge it
## is a red build rather than a sentence nobody re-counts.
extends GutTest

const GDD := "res://docs/10_gdd/02_player_controller.md"


func _table_states() -> PackedStringArray:
	# Rows of §3.1 look like: | **Idle** | ... |
	var text := SourceScanner.read(GDD)
	var start := text.find("### 3.1 State table")
	var finish := text.find("### 3.2", start)
	assert_gt(start, -1, "GDD-02 §3.1 is missing")
	var section := text.substr(start, finish - start)

	var out: PackedStringArray = []
	var re := RegEx.create_from_string("\\|\\s\\*\\*([A-Za-z]+)\\*\\*\\s\\|")
	for m: RegExMatch in re.search_all(section):
		out.append(m.get_string(1))
	return out


func test_the_table_scan_found_the_rows() -> void:
	# Guards the guard: a failed scan would make the comparison below vacuous.
	assert_gt(_table_states().size(), 10, "the §3.1 table scan matched almost nothing")


func test_there_are_fifteen_states() -> void:
	assert_eq(PawnStateId.ALL.size(), 15, "GDD-02 §3.1 lists fifteen states")


func test_code_and_the_normative_table_agree() -> void:
	var table := _table_states()
	var code := PawnStateId.ALL

	var missing_from_code: PackedStringArray = []
	for name: String in table:
		if not code.has(StringName(name)):
			missing_from_code.append(name)

	var missing_from_table: PackedStringArray = []
	for id: StringName in code:
		if not table.has(String(id)):
			missing_from_table.append(String(id))

	var problems: PackedStringArray = []
	if not missing_from_code.is_empty():
		problems.append("in GDD-02 §3.1 but not PawnStateId: " + ", ".join(missing_from_code))
	if not missing_from_table.is_empty():
		problems.append("in PawnStateId but not GDD-02 §3.1: " + ", ".join(missing_from_table))
	assert_eq(
		problems.size(),
		0,
		"The state list and the normative table disagree.\n" + "\n".join(problems)
	)


func test_no_state_id_is_declared_twice() -> void:
	var seen: Dictionary = {}
	var dupes: PackedStringArray = []
	for id: StringName in PawnStateId.ALL:
		if seen.has(id):
			dupes.append(String(id))
		seen[id] = true
	assert_eq(dupes.size(), 0, "duplicate state ids: " + ", ".join(dupes))


func test_the_locomotion_group_is_a_subset() -> void:
	# GDD-02 §3 draws these inside `state "Locomotion"` and declares several
	# transitions against the group. A member that is not a real state would make
	# those edges point nowhere.
	for id: StringName in PawnStateId.LOCOMOTION:
		assert_true(PawnStateId.exists(id), "%s is in LOCOMOTION but not ALL" % id)
	assert_false(PawnStateId.is_locomotion(PawnStateId.KILL_ANIM), "KillAnim is not locomotion")
	assert_true(PawnStateId.is_locomotion(PawnStateId.SPRINT), "Sprint is locomotion")
