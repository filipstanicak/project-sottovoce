## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **A CI GUARD ENUMERATES THROUGH `.ci/repo_files.sh`, NEVER THROUGH A BARE
## `git ls-files`, AND NEVER REPORTS SUCCESS OVER AN EMPTY SCAN.**
##
## `git ls-files` fails outside a git work tree. This project's checkpoint
## procedure verifies from `git archive HEAD | tar -x` (CLAUDE.md trap 3,
## `.claude/commands/save.md` §8), which is not one — so in the one place the
## guards most needed to work, git wrote "fatal: not a git repository" to
## stderr, the read loop received nothing, and the guard printed "clean".
##
## Why review misses this: the failing call is invisible. `git ls-files` in a
## process substitution swallows its own exit status, the loop body simply never
## runs, and `status` is still 0 at the end. The script reads exactly as
## intended and passes in the work tree where anyone would test it.
##
## Both merged guards shipped that way until 2026-08-05. Measured, not assumed:
## a planted banned term under `scripts/` and an unlicensed file under
## `assets/` were waved through by an extraction of 739 files, scanning none.
## That is the shape `.ci/run_gut.sh` exists for — the green was the defect.
extends GutTest

const CI_DIR := "res://.ci"

## The only script permitted to call `git ls-files`. It is the one that knows
## what to do when the call fails.
const ENUMERATOR := "repo_files.sh"

## Guards that must load the shared enumeration rather than rolling their own.
const GUARDS: Array[String] = ["ip_guard.sh", "check_asset_inventory.sh"]


func _shell_scripts() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(CI_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".sh"):
			out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func test_the_scan_found_the_ci_scripts() -> void:
	# Guards the guard, which is the whole point of this file: an empty file list
	# would pass every check below in silence. Exactly the defect being guarded.
	var found := _shell_scripts()
	assert_true(found.has(ENUMERATOR), "%s is missing from %s" % [ENUMERATOR, CI_DIR])
	for guard: String in GUARDS:
		assert_true(found.has(guard), "%s is missing from %s" % [guard, CI_DIR])
	assert_gt(found.size(), 2, "the .ci shell-script scan matched almost nothing")


func test_only_the_enumerator_calls_git_ls_files() -> void:
	var violations: PackedStringArray = []
	for name: String in _shell_scripts():
		if name == ENUMERATOR:
			continue
		var path := CI_DIR.path_join(name)
		for pair: Array in SourceScanner.code_lines(path):
			if String(pair[1]).contains("git ls-files"):
				violations.append("%s:%d" % [name, int(pair[0])])
	assert_eq(
		violations.size(),
		0,
		(
			"A CI guard enumerates with a bare `git ls-files`.\n"
			+ "It fails outside a work tree, the loop then runs zero times, and the\n"
			+ "guard reports success having scanned nothing. Use repo_files_load.\n"
			+ "\n".join(violations)
		)
	)


func test_every_guard_loads_the_shared_enumeration() -> void:
	for name: String in GUARDS:
		var body := SourceScanner.read(CI_DIR.path_join(name))
		assert_true(body.contains(ENUMERATOR), "%s does not source %s" % [name, ENUMERATOR])
		assert_true(body.contains("repo_files_load"), "%s does not call repo_files_load" % name)


func test_the_enumerator_refuses_an_empty_or_wrong_scan() -> void:
	# The two refusals are the fix. If either disappears the guards go back to
	# passing over nothing, and every check above still passes.
	var body := SourceScanner.read(CI_DIR.path_join(ENUMERATOR))
	assert_true(body.contains("REPO_FILES_ANCHOR"), "the wrong-directory anchor is gone")
	assert_true(body.contains('[ "${#REPO_FILES[@]}" -eq 0 ]'), "the empty-scan refusal is gone")
	assert_true(body.contains("project.godot"), "the anchor no longer names a real file")
