## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **NO CODE PATH ASSIGNS TO A PLAYER SCORE OUTSIDE THE FOLD.** ADR-0004,
## TDD-10 §1.1, US-0064.
##
## The running-integer design fails four requirements at once, and the classic
## mitigation — a total *plus* a parallel stats dictionary — creates two sources of
## truth that diverge. **The visible symptom is a results screen that adds up to a
## different number from the scoreboard**, at the one moment in the match the game
## has the player's full attention.
##
## So there is exactly one accumulation in the codebase and it lives in
## `ScoreFold`. This refuses a second one.
extends GutTest

const FOLD := "res://scripts/core/score/score_fold.gd"
const SCORE_DIR := "res://scripts/core/score"

## Where a score total could be accumulated without anybody noticing.
const SCANNED: Array[String] = [
	"res://scripts/core",
	"res://scripts/systems",
	"res://scripts/net",
	"res://scripts/server",
	"res://scripts/pawn",
	"res://scripts/mirrors",
	"res://scripts/presentation",
]

## An accumulation into, or a reassignment of, something called a score. `+=` is
## the running integer itself; `score = ` catches somebody replacing the log
## rather than appending to it, which would throw a match's history away.
const ACCUMULATIONS: Array[String] = [
	"score +=",
	"score -=",
	"_score +=",
	"_score -=",
	"score = ",
]

## Client layers that may not so much as name the log. The log is server-owned,
## and a client holding one would be a client that can invent points.
const CLIENT_ONLY: Array[String] = [
	"res://scripts/presentation",
	"res://scripts/mirrors",
	"res://scripts/pawn",
	"res://scripts/net/client",
]


func test_the_scan_reaches_the_code_at_all() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every assertion below passes over an empty
	# file list, which is how `ip-guard` reported clean over zero of 739 files for
	# two milestones.
	var counted := 0
	for folder: String in SCANNED:
		counted += SourceScanner.gd_files(folder).size()
	assert_gt(counted, 150, "the scan found %d files, so it is not scanning" % counted)


func test_nothing_accumulates_a_score_outside_the_fold() -> void:
	var violations: PackedStringArray = []
	for folder: String in SCANNED:
		for path: String in SourceScanner.gd_files(folder):
			if path.begins_with(SCORE_DIR):
				continue
			for row: Array in SourceScanner.code_lines(path):
				var line := str(row[1])
				for needle: String in ACCUMULATIONS:
					if line.contains(needle):
						violations.append(
							"%s:%d %s" % [path.get_file(), int(row[0]), line.strip_edges()]
						)
	assert_eq(
		violations.size(),
		0,
		"a score is accumulated outside ScoreFold (TDD-10 §1.1):\n" + "\n".join(violations)
	)


func test_the_fold_is_where_the_accumulation_lives() -> void:
	# **THE COUNTERFACTUAL, AND ITS FIRST VERSION WAS WRONG IN AN INSTRUCTIVE WAY.**
	# It scanned `ScoreFold` for the same needles as the guard above and went red on
	# correct code: the fold accumulates into a dictionary, not with `+=`, so the
	# needle list described a shape the one legitimate accumulator does not use.
	# **A counterfactual written as a string match is only as good as the guard's
	# vocabulary**; this asks the fold to do the thing instead.
	var rules := Tuning.match_rules
	var events: Array[ScoreEvent] = [
		ScoreEvent.new(1, ScoreAward.new(10, Ids.SCORE_CONTRACT, 7, 8, 100.0), rules),
		ScoreEvent.new(2, ScoreAward.new(10, Ids.SCORE_SILENT, 7, 8, 200.0), rules),
	]
	assert_eq(
		ScoreFold.total_for(events, 7),
		300,
		"ScoreFold no longer adds two events up, so the guard above asserts over nothing"
	)


func test_the_fold_is_pure() -> void:
	# TDD-10 §1.3: no autoload, no scene, no clock. `Tuning` is Core's one permitted
	# autoload and the fold does not need even that — the points are frozen on the
	# events, so re-reading the tuning could only produce a second answer.
	for term: String in ["Tuning.", "Net.", "EventBus", "get_node", "get_tree", "Time."]:
		assert_false(SourceScanner.code_contains(FOLD, term), "ScoreFold reaches for `%s`" % term)


func test_no_client_layer_holds_the_log() -> void:
	# Server-owned. A client that could append is a client that can award itself
	# points, which is never-do #2 with a scoreboard attached.
	for folder: String in CLIENT_ONLY:
		for path: String in SourceScanner.gd_files(folder):
			assert_false(
				SourceScanner.code_contains(path, "ScoreLog"),
				"%s holds a ScoreLog; the log is server-owned" % path.get_file()
			)
