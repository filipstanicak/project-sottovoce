## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **CLAUDE.md'S TEST-SCRIPT COUNTS MATCH WHAT IS ON DISK.**
##
## CLAUDE.md is the first thing a fresh session reads, and its own header says a
## stale version is worse than none. Its "Tests" row read **119 arch + 515 unit +
## 132 integration for twelve pull requests** — from US-0029 to US-0031 — while
## the real numbers climbed to 34/64/25 scripts. Nobody noticed, because a number
## in a table is not executed by anything.
##
## **THE CAUSE IS WORTH MORE THAN THE SYMPTOM.** Every attempted update was an
## unasserted `str.replace` against a string that had already changed. Python's
## `replace` reports success by doing nothing, so three separate checkpoints each
## "updated" the line and each silently matched zero characters. That is trap 3's
## family in a text editor rather than a test runner: **an operation whose failure
## mode is indistinguishable from its success.**
##
## Only the **script** counts are guarded here, not the assertion counts. Script
## counts are readable from disk; assertion counts need the suites to actually
## run, which a suite cannot do to itself. CLAUDE.md says which is which, so
## nobody trusts the wrong half.
extends GutTest

const CLAUDE_MD := "res://CLAUDE.md"

## Directory -> the label CLAUDE.md uses for it.
const SUITES: Dictionary = {
	"res://test/arch": "arch",
	"res://test/unit": "unit",
	"res://test/integration": "integration",
}


func _count_scripts(root: String) -> int:
	var total := 0
	var dir := DirAccess.open(root)
	if dir == null:
		return -1
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				total += _count_scripts(root.path_join(entry))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			total += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return total


func _claude_md() -> String:
	return FileAccess.get_file_as_string(CLAUDE_MD)


func test_the_file_was_actually_read() -> void:
	# Guards the guard. A moved or renamed CLAUDE.md reads as an empty string, and
	# an empty string contains no wrong numbers at all.
	assert_gt(_claude_md().length(), 5000, "CLAUDE.md is missing or unexpectedly small")


func test_every_suite_was_actually_counted() -> void:
	# The same failure from the other direction: a suite directory that cannot be
	# opened returns -1 rather than 0, so a renamed folder fails loudly instead of
	# reporting that no tests exist.
	for root: String in SUITES:
		assert_gt(_count_scripts(root), 0, "%s could not be counted — did it move?" % root)


func test_claude_md_states_the_current_script_counts() -> void:
	# **THE ASSERTION THE FILE IS FOR.** The Tests row must name the real number of
	# scripts in each suite. It is deliberately a substring search rather than a
	# parse of the table: the row's prose gets rewritten often, and a guard that
	# broke on rewording would be deleted the first time somebody edited it.
	var text := _claude_md()
	var wrong: PackedStringArray = []
	for root: String in SUITES:
		var label: String = SUITES[root]
		var expected := "%d %s" % [_count_scripts(root), label]
		if not text.contains(expected):
			wrong.append("expected CLAUDE.md to say '%s'" % expected)

	assert_eq(
		wrong.size(),
		0,
		(
			"CLAUDE.md's test-script counts are stale.\n"
			+ "It is the first thing a fresh session reads, and its own header says a\n"
			+ "stale version is worse than none. Update the Tests row.\n"
			+ "\n".join(wrong)
		)
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification. A number no suite could ever hold must not be found, or the
	# substring search is matching something it should not.
	assert_false(
		_claude_md().contains("99999 unit"),
		"the search matches a count that cannot exist — it is not discriminating"
	)
