## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## `/CLAUDE.md` is loaded into every agent session, and its stable half is
## authored in the corpus as `docs/30_bible/CLAUDE.md_SEED.md` so it is reviewed
## like every other bible document rather than edited at the root by whoever
## happened to be there.
##
## **THE SEED CLAIMED THIS GUARD EXISTED FROM US-0001 AND IT DID NOT.** Named in
## the seed's own header, never written, so the two files were free to diverge —
## and did: the `.ci/run_gut.sh` command block was added at the root in US-0022
## and never copied back. Same vacuously-green shape as CLAUDE.md trap 3. A
## document asserting a check that does not exist is worse than one asserting
## nothing, because it stops anyone from looking.
##
## The relationship is a SUPERSET, not equality. The root carries one section the
## seed must not — "Where the work is right now", the traps and the local
## environment — because that changes with every story and names the machine the
## toolchain sits on. Checking a copy of it into the corpus would mean editing
## two files per story to preserve something stale by design a week later.
extends GutTest

const SEED := "res://docs/30_bible/CLAUDE.md_SEED.md"
const ROOT := "res://CLAUDE.md"

## Where the seed's frontmatter and editing note end and the brief begins.
const BODY_STARTS := "# Project Sottovoce"

## The section that lives at the root and nowhere else.
const LIVE_SECTION := "## Where the work is right now"


## Non-blank lines of a file, trimmed, from `from` onward if given.
func _lines(path: String, from: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	var started := from == ""
	for raw: String in SourceScanner.read(path).split("\n"):
		var line := raw.strip_edges()
		if not started:
			if line == from:
				started = true
			else:
				continue
		if line != "":
			out.append(line)
	return out


func test_both_files_are_readable() -> void:
	# Guards the guard. A typo'd path would make every assertion below pass over
	# two empty arrays, which is precisely the failure this file exists to end.
	assert_gt(_lines(SEED).size(), 100, "the seed is empty or missing: " + SEED)
	assert_gt(_lines(ROOT).size(), 100, "the root brief is empty or missing: " + ROOT)


func test_every_line_of_the_seed_appears_at_the_root_in_order() -> void:
	# A subsequence check rather than equality, because the root is a documented
	# superset. It still catches everything that matters: a rule edited on one
	# side only, a section dropped, or two sections swapped.
	var seed := _lines(SEED, BODY_STARTS)
	var root := _lines(ROOT)
	var at := 0
	var missing: PackedStringArray = []
	for line: String in seed:
		var found := -1
		for i: int in range(at, root.size()):
			if root[i] == line:
				found = i
				break
		if found < 0:
			missing.append(line)
		else:
			at = found + 1
	assert_eq(
		missing.size(),
		0,
		(
			"CLAUDE.md has drifted from its seed. Copy the change across, in whichever\n"
			+ "direction is correct — the root is the one that actually drifts.\n"
			+ "Missing from CLAUDE.md, or out of order:\n  "
			+ "\n  ".join(missing)
		)
	)


func test_the_live_section_is_at_the_root_only() -> void:
	# The other half of the contract. A "Where the work is right now" checked into
	# the corpus would be edited once, forgotten, and then read by a fresh session
	# as though it were current.
	assert_true(_lines(ROOT).has(LIVE_SECTION), "CLAUDE.md has lost its %s section" % LIVE_SECTION)
	assert_false(
		_lines(SEED).has(LIVE_SECTION),
		"the seed has acquired the live section — it belongs at the root only"
	)


func test_the_brief_stays_short_enough_to_be_read() -> void:
	# The seed's own rule: ~250 lines. It is loaded into every agent session, and
	# a brief nobody finishes reading is a brief nobody follows. The root is
	# allowed to be longer because the live section is the part a session skims
	# for what changed.
	var seed_length := SourceScanner.read(SEED).split("\n").size()
	assert_lt(seed_length, 300, "the seed is %d lines — over its own ~250 budget" % seed_length)
