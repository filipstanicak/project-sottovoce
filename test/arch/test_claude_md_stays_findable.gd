## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **`CLAUDE.md` STAYS SHORT ENOUGH TO FIND A RULE IN, AND ITS REFERENCE SECTIONS
## STAY WHERE A COLD SESSION LOOKS.**
##
## This file is loaded into every agent session and its own header says a stale
## version is worse than none. Nothing said anything about a **long** one, and by
## 2026-09-08 it was **6 594 lines** — because every checkpoint prepends a section
## to "Where the work is right now" and no checkpoint had ever removed one.
##
## **THE LENGTH WAS THE SYMPTOM AND THE ORDER WAS THE DEFECT.** One section held
## 3 301 lines of M0-M4 history, and filed *underneath* it were the state tables,
## the eighteen traps and the local environment — the three things a session needs
## before it does anything, sitting at the bottom of a section titled about M4's
## story list. A second agent joining the project said it plainly: thousands of
## lines make it hard to find which rules actually bind.
##
## **AND THE FIX IS NOT ONLY DELETION.** The reasoning in those pages is worth
## keeping: this project has repeatedly been bitten by a rule applied without its
## reason. The `-s` autoload cascade is the sharpest instance — the fix **was
## already in this file**, three sections above the error it explained, and went
## unconnected for four milestones. So the history moves to
## `docs/00_meta/history/` and **every file there must be linked from the manual**,
## which is what stops an archive becoming write-only.
extends GutTest

const CLAUDE_MD := "res://CLAUDE.md"
const ARCHIVE_DIR := "res://docs/00_meta/history"

## Room for several checkpoints before archiving is forced again. It was 6 594 and
## is 3 334 after the M0-M4 move; passing this means the oldest narrative sections
## go to the archive, not that a finding gets deleted.
const MAX_LINES := 4000

## In the order a cold session meets them: what is true now, what is not done, what
## will cost an hour, what this machine needs, and where the reasoning went.
const REFERENCE_SECTIONS: Array[String] = [
	"## Where the work is right now",
	"## The state of the build",
	"## What is deliberately unticked",
	"## Eighteen things that will cost you an hour if you do not know them",
	"## Local environment",
	"## The record before M5, and why it is not in this file",
	"## Fresh session? Read these four first",
]


func _text() -> String:
	return FileAccess.get_file_as_string(CLAUDE_MD)


## PREMISE. A moved or truncated manual contains no long file, no missing heading
## and no unlinked archive, and would pass every assertion below.
func test_the_manual_was_actually_read() -> void:
	var text := _text()
	assert_gt(text.length(), 20000, "CLAUDE.md is missing or unexpectedly small")
	assert_gt(text.split("\n").size(), 1000, "CLAUDE.md is far shorter than any real version")


func test_the_manual_stays_under_its_budget() -> void:
	var lines := _text().split("\n").size()
	assert_lt(
		lines,
		MAX_LINES,
		(
			(
				"CLAUDE.md is %d lines against a budget of %d.\n"
				+ "Move the OLDEST sections of 'Where the work is right now' into\n"
				+ "docs/00_meta/history/, add them to the archive table, and link the file.\n"
				+ "Archive the reasoning; never delete a live finding — the tables and the\n"
				+ "unticked list are where a fact stays after its story is archived."
			)
			% [lines, MAX_LINES]
		)
	)


## Presence is not enough: these were present before, buried under 3 301 lines of
## history inside a section about something else.
func test_every_reference_section_is_present_and_in_order() -> void:
	var lines := _text().split("\n")
	var at := -1
	for heading: String in REFERENCE_SECTIONS:
		var found := -1
		for i: int in lines.size():
			if lines[i] == heading:
				found = i
				break
		assert_gt(found, -1, "CLAUDE.md has lost its section: %s" % heading)
		if found == -1:
			return
		assert_gt(
			found,
			at,
			(
				(
					"%s is out of order in CLAUDE.md. A cold session reads top down, and\n"
					+ "these sections are ordered so the reference material arrives before\n"
					+ "the reasoning behind it."
				)
				% heading
			)
		)
		at = found


## An archive nothing routes into is an archive nobody reads, which is the failure
## this move exists to avoid rather than create.
func test_every_archived_document_is_linked_from_the_manual() -> void:
	var dir := DirAccess.open(ARCHIVE_DIR)
	assert_not_null(dir, "the archive directory %s is missing" % ARCHIVE_DIR)
	if dir == null:
		return
	var text := _text()
	var seen := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".md"):
			seen += 1
			assert_true(
				text.contains(entry),
				(
					(
						"docs/00_meta/history/%s is archived and NOT linked from CLAUDE.md.\n"
						+ "Add it to the archive table, or nobody will find the reasoning in it."
					)
					% entry
				)
			)
		entry = dir.get_next()
	dir.list_dir_end()
	assert_gt(seen, 0, "the archive holds no documents — this guard is testing nothing")
