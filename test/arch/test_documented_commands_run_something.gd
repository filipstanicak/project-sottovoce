## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY DOCUMENTED WAY OF RUNNING THE SUITES MUST ACTUALLY RUN THEM.**
##
## Why review misses this: the command *looks* right, and running it prints
## *"On the one hand nothing failed, on the other hand nothing did anything"* —
## which is GUT's report for **zero tests**, and reads as a pass to anybody
## skimming. Without `-ginclude_subdirs` it scans only the top level of `-gdir`
## and every suite in this project is nested.
##
## **TEN DOCUMENTED COMMANDS ACROSS FIVE FILES RAN ZERO TESTS UNTIL 2026-09-02**,
## including `DEFINITION_OF_DONE.md`'s pre-commit line — which said the command
## *"passes"*, and it did, over nothing — and `TEST_PLAN.md` §9's four, one of
## which pointed at `test/metrics/`, a directory holding a `.gdkeep` and no tests
## at all. Trap 10's family, in the documents that teach the process.
##
## The fix in every case is `.ci/run_gut.sh`, which counts the scripts on disk and
## refuses to pass over a short run. This guard is narrower on purpose: it forbids
## the **silent** failure, not the raw invocation, because CLAUDE.md documents the
## by-hand form deliberately and says the flag is not optional.
extends GutTest

const ROOTS: Array[String] = ["res://docs", "res://"]
const RUNNER := "gut_cmdln"
const REQUIRED := "-ginclude_subdirs"


## Every markdown file in the corpus, plus the ones at the repository root.
## `SourceScanner` walks `.gd` only, so this is its own walker.
func _markdown() -> PackedStringArray:
	var out: PackedStringArray = []
	_walk("res://docs", out)
	for name: String in ["res://CLAUDE.md", "res://README.md"]:
		if FileAccess.file_exists(name):
			out.append(name)
	return out


func _walk(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_walk(full, out)
		elif entry.ends_with(".md"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func test_the_scan_reaches_the_corpus_at_all() -> void:
	# **THE VACUOUS-SUCCESS GUARD**, and this file of all files needs one: a walker
	# that found no markdown would report every documented command correct.
	assert_gt(_markdown().size(), 20, "the markdown scan found almost nothing — paths are stale")


func test_the_scan_finds_the_commands_it_is_about() -> void:
	var found := 0
	for path: String in _markdown():
		for line: String in SourceScanner.read(path).split("\n"):
			if line.contains(RUNNER):
				found += 1
	assert_gt(found, 0, "no documented GUT command was found at all — this guard checks nothing")


## **A DOCUMENTED COMMAND THAT RUNS NOTHING IS WORSE THAN NO COMMAND**, because it
## is followed and believed.
func test_no_documented_gut_command_silently_runs_nothing() -> void:
	var offenders: PackedStringArray = []
	for path: String in _markdown():
		var lines := SourceScanner.read(path).split("\n")
		for i: int in lines.size():
			var line: String = lines[i]
			if not line.contains(RUNNER) or line.contains(REQUIRED):
				continue
			offenders.append("%s:%d — %s" % [path, i + 1, line.strip_edges()])
	offenders.sort()
	assert_eq(
		offenders.size(),
		0,
		(
			(
				"A documented command invokes GUT without `%s`, so it scans only the top\n"
				+ "level of -gdir, finds no test_*.gd, and prints GUT's zero-test report — which\n"
				+ "reads as a pass. Use `.ci/run_gut.sh <dir> <name>`, which refuses a short run.\n"
				+ "\n".join(offenders)
			)
			% REQUIRED
		)
	)


## **AND THE DIRECTORY ONE OF THOSE COMMANDS POINTED AT HELD NO TESTS.**
## `test/metrics/` was declared in TDD-02 from M0, held a `.gdkeep`, and was named
## in `TEST_PLAN` §9's *before every PR* list. Its assertions had been written into
## `test/unit/core/map/` instead and had run in CI all along.
func test_no_documented_suite_directory_is_empty() -> void:
	var missing: PackedStringArray = []
	for path: String in _markdown():
		for line: String in SourceScanner.read(path).split("\n"):
			for token: String in line.split(" "):
				if not token.begins_with("res://test/") and not token.begins_with("test/"):
					continue
				var dir := token.trim_prefix("-gdir=").replace("res://", "res://")
				if not dir.begins_with("res://"):
					dir = "res://" + dir
				dir = dir.rstrip("`\"',.")
				if DirAccess.dir_exists_absolute(dir) and _scripts_under(dir) == 0:
					missing.append("%s names %s, which holds no tests" % [path, dir])
	assert_eq(missing.size(), 0, "\n".join(missing))


func _scripts_under(path: String) -> int:
	var found: PackedStringArray = []
	_walk_gd(path, found)
	return found.size()


func _walk_gd(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_walk_gd(full, out)
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
