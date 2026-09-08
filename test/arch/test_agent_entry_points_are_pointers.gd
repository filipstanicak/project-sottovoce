## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY AGENT ENTRY POINT IS A POINTER, AND ITS TARGET EXISTS.**
##
## More than one agent works this repository, and each brings its own convention
## for the file it reads first: `CLAUDE.md` for one, `AGENTS.md` for another, a
## slash command here, a skill file there. Left alone, each convention grows a
## full copy of whatever it needs — and then the copies disagree.
##
## **MEASURED, NOT FEARED (2026-09-08).** `AGENTS.md` held a 6 529-line verbatim
## copy of `CLAUDE.md`. Its test-count row was two days stale, its header named
## `docs/30_bible/Codex.md_SEED.md` as its source — **a file that has never
## existed** — and it claimed to be checked by `test_claude_md_synced.gd`, which
## reads `CLAUDE.md` and its seed and had never opened it. Separately, the
## checkpoint procedure existed twice and the two had **diverged in substance**:
## one instructed its agent to write the live project state into `CLAUDE.md`, the
## other into `AGENTS.md`. Neither instruction was wrong on its own terms, which
## is precisely why a year of reading either one would not have found it.
##
## **THE TARGET IS RESOLVED, NOT MERELY MENTIONED, AND THAT IS THE HALF THAT
## MATTERS.** A line count alone would have passed every one of the defects above:
## a short file can carry a confident instruction to a document that is not there.
## `Codex.md_SEED.md` is exactly that failure, and it sat in a header telling every
## reader the file was generated and checked.
##
## Sixth instance of the shape this corpus keeps paying for, after
## `NETWORK_PROTOCOL.md`, the seed's phantom guard, TDD-12 §11's twelve absent
## hooks, `test/metrics/` and `AGENTS.md` itself: **a document asserting a check
## that does not exist is worse than one asserting nothing.**
extends GutTest

## Entry point -> the repo-relative path it must name and which must resolve.
const ENTRY_POINTS: Dictionary = {
	"res://AGENTS.md": "CLAUDE.md",
	"res://.claude/commands/save.md": "docs/30_bible/CHECKPOINT.md",
	"res://.agents/skills/source-command-save/SKILL.md": "docs/30_bible/CHECKPOINT.md",
}

## Generous enough for a frontmatter block and the reason the file is a pointer,
## far short of any of the documents it can point at. The copy this guard was
## written against was 6 529 lines; the shortest real manual here is over 400.
const MAX_LINES := 60

## A target that resolves but is a stub would satisfy the letter of the rule.
const MIN_TARGET_LINES := 80


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _line_count(path: String) -> int:
	return _text(path).split("\n").size()


## PREMISE. Every assertion below reads a file; a path that silently returns an
## empty string contains no copy, names no wrong target and passes everything.
func test_every_entry_point_was_actually_read() -> void:
	assert_gt(ENTRY_POINTS.size(), 0, "the entry-point table is empty — this guard tests nothing")
	for path: String in ENTRY_POINTS:
		assert_true(FileAccess.file_exists(path), "%s is missing" % path)
		assert_gt(_text(path).length(), 100, "%s read as empty or near-empty" % path)


func test_no_entry_point_carries_a_copy() -> void:
	for path: String in ENTRY_POINTS:
		var lines := _line_count(path)
		assert_lt(
			lines,
			MAX_LINES,
			(
				(
					"%s is %d lines. An agent entry point is a POINTER — see its target, %s.\n"
					+ "A second copy of a manual or a procedure does not stay a copy; the two\n"
					+ "already diverged once, and the divergence was instructed rather than accidental."
				)
				% [path, lines, ENTRY_POINTS[path]]
			)
		)


func test_every_pointer_names_its_target() -> void:
	for path: String in ENTRY_POINTS:
		var target: String = ENTRY_POINTS[path]
		assert_true(
			_text(path).contains(target),
			"%s never names %s, so a reader has nowhere to go" % [path, target]
		)


## The half a line count cannot do. `AGENTS.md` named a seed that has never
## existed, in a header claiming the file was generated from it and checked.
func test_every_named_target_resolves() -> void:
	for path: String in ENTRY_POINTS:
		var target: String = "res://" + String(ENTRY_POINTS[path])
		assert_true(
			FileAccess.file_exists(target), "%s points at %s, which does not exist" % [path, target]
		)
		assert_gt(
			_line_count(target),
			MIN_TARGET_LINES,
			"%s points at %s, which is too short to be the real procedure" % [path, target]
		)
