## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **NOTHING A CLIENT CHOSE MAY ORDER A KILL, AND THE REWIND HAS TWO CALL SITES.**
## ADR-0010, TDD-04 §8.4, US-0060.
##
## Two rules from the same decision:
##
## 1. **Contests resolve on server receive order.** `InputCommand` no longer
##    carries a client clock at all — the two bytes that were `client_tick` became
##    `acked_tick` in US-0031 — and `acked_tick` is still client-supplied. It asks
##    for a delta baseline and orders nothing. A combat rule that read it would
##    hand the contest window to whoever lies best, and would look exactly like a
##    sensible tie-break at the call site.
## 2. **Only `KillSystem.validate()` and `StunSystem.validate()` rewind.**
##    ADR-0010's compliance list says so in as many words, and a third caller
##    requires an amendment. The mixed policy — positions yes, tier no, contract
##    no, cooldowns no — is a set of rules a developer has to know, and the ADR
##    names this exact failure: *"the kind of thing that gets quietly broken by
##    someone adding a fourth validated action without reading this."*
##
## Why review misses it: every one of these reads compiles, runs, and produces a
## plausible number. Nothing fails until somebody works out that low-ping players
## win every contest for a reason that is not their ping.
extends GutTest

## Where combat rules live. Scanned in full, so a file added here is covered the
## day it appears rather than the day somebody remembers to list it.
const COMBAT_DIRS: Array[String] = [
	"res://scripts/core/combat",
	"res://scripts/systems/combat",
]

## The client-supplied field. Legitimate everywhere on the wire; forbidden here.
const CLIENT_SUPPLIED := "acked_tick"

## **ADR-0010 NAMES ITS TWO CALL SITES**, so this guard names them rather than
## counting to two. A count alone would permit any second caller, and the risk the
## ADR describes is precisely a *different* action being validated against a
## rewound world by somebody who never read the mixed policy.
##
## `SYS-STUN` is US-0061, so today only the first of these exists.
## **STILL EXACTLY TWO VERBS; ONE OF THEM MOVED FILE AT US-0070.**
## `KillSystem`'s rewind is `KillRewind`'s now — the file passed 400 lines when
## `ABIL-LUNGE`'s arrival path landed in it. **This list is not the guarantee**;
## `test_only_the_kill_system_holds_the_kill_rewind` below is, because a list of
## filenames is exactly what a third system would get itself added to.
const REWIND_CALL_SITES: Array[String] = [
	"res://scripts/systems/combat/kill_rewind.gd",
	"res://scripts/systems/combat/stun_system.gd",
]

## The one class allowed to hold a `KillRewind`. Extracting the rewind into its
## own file would otherwise turn ADR-0010's two-caller rule into a doorway
## anything could walk through.
const REWIND_OWNERS: Array[String] = ["res://scripts/systems/combat/kill_system.gd"]


func test_no_combat_code_reads_a_client_supplied_number() -> void:
	var violations: PackedStringArray = []
	var scanned := 0
	for dir: String in COMBAT_DIRS:
		for path: String in SourceScanner.gd_files(dir):
			scanned += 1
			for row: Array in SourceScanner.code_lines(path):
				if String(row[1]).contains(CLIENT_SUPPLIED):
					violations.append("%s:%d" % [path, int(row[0])])
	# **THE VACUOUS-SUCCESS GUARD.** A scan over a directory that no longer exists
	# reports clean, which is exactly what this file would do the day somebody
	# moves the combat code.
	assert_gt(scanned, 2, "the combat scan found almost no files — the paths are stale")
	assert_eq(
		violations.size(),
		0,
		(
			"Combat code reads `acked_tick`, which the client chooses.\n"
			+ "Contests resolve on server receive order (ADR-0010). Use the tick and the\n"
			+ "arrival ordinal that `MatchDirector.enqueue_input` stamps.\n"
			+ "\n".join(violations)
		)
	)


func test_the_rewind_has_at_most_the_two_call_sites_the_adr_allows() -> void:
	var callers: PackedStringArray = []
	for root: String in ["res://scripts/core", "res://scripts/systems", "res://scripts/net"]:
		for path: String in SourceScanner.gd_files(root):
			if path.ends_with("lag_comp_history.gd"):
				continue  # the definition, not a call site
			for row: Array in SourceScanner.code_lines(path):
				if String(row[1]).contains("lag_comp.rewind("):
					callers.append("%s:%d" % [path, int(row[0])])
	assert_gt(callers.size(), 0, "nothing rewinds at all — this guard is checking nothing")
	var strangers: PackedStringArray = []
	for caller: String in callers:
		# `res://` contains a colon, so the path is everything before the LAST one.
		if not REWIND_CALL_SITES.has(caller.substr(0, caller.rfind(":"))):
			strangers.append(caller)
	assert_eq(
		strangers.size(),
		0,
		(
			"Something other than KillSystem or StunSystem rewinds the world. ADR-0010 "
			+ "allows those two; a third requires an amendment, because tier, contract "
			+ "and cooldowns are deliberately NOT rewound and each new caller is a "
			+ "fresh chance to get that wrong: "
			+ ", ".join(strangers)
		)
	)


func test_the_clamp_is_written_in_exactly_one_place() -> void:
	# ADR-0010's second compliance line: *"`rewind_ms()` clamps with no path that
	# bypasses the clamp."* The way that stays true is that `TUN-NET-LAGCOMP-MIN`
	# and `-MAX` are readable from one file — a second reader is a second clamp, and
	# two clamps drift the first time one of them is retuned.
	var readers: PackedStringArray = []
	for root: String in ["res://scripts/core", "res://scripts/systems", "res://scripts/net"]:
		for path: String in SourceScanner.gd_files(root):
			if path.begins_with("res://scripts/core/tuning/"):
				continue  # where the fields are declared and the invariants live
			for row: Array in SourceScanner.code_lines(path):
				var line := String(row[1])
				if line.contains("lagcomp_min") or line.contains("lagcomp_max"):
					readers.append("%s:%d" % [path, int(row[0])])
	assert_gt(readers.size(), 0, "nothing reads the clamp bounds — this guard is checking nothing")
	for reader: String in readers:
		assert_true(
			reader.begins_with("res://scripts/core/combat/rewind_clamp.gd"),
			"the rewind clamp is read outside RewindClamp: " + reader
		)


func test_the_arrival_ordinal_is_stamped_where_arrival_happens() -> void:
	# The positive half of rule 1. Server receive order exists in exactly one place
	# in the process — `MatchDirector.enqueue_input`, which sees packets in the
	# order the socket delivered them. Everything downstream walks dictionaries,
	# whose order is *join* order, and a tie-break on join order would hand the
	# earliest-joined player every contest for the whole match.
	var writers: PackedStringArray = []
	var roots := ["core", "systems", "net", "server"]
	for root: String in roots:
		for path: String in SourceScanner.gd_files("res://scripts/" + root):
			if path.ends_with("input_command.gd"):
				continue  # the declaration
			for row: Array in SourceScanner.code_lines(path):
				if String(row[1]).contains("received_ordinal ="):
					writers.append("%s:%d" % [path, int(row[0])])
	assert_eq(
		writers.size(),
		1,
		(
			"`received_ordinal` is written somewhere other than MatchDirector.enqueue_input.\n"
			+ "It is the server's record of packet arrival order and has one writer.\n"
			+ "\n".join(writers)
		)
	)
	assert_true(
		writers[0].contains("match_director.gd"), "the ordinal is stamped in the wrong place"
	)


func test_the_ordinal_never_reaches_the_wire() -> void:
	# It is server-side scratch. A field that a client could set would be a client
	# clock with a different name, which is the whole thing ADR-0010 refuses.
	var protocol := SourceScanner.read("res://scripts/net/protocol/input_codec.gd")
	assert_false(
		protocol.contains("received_ordinal"),
		"the arrival ordinal is being serialised — a client can now choose its own place in a race"
	)


## **WIDENING AN ALLOWLIST IS HOW A GUARD GETS HOLLOWED OUT, SO THIS IS THE HALF
## THAT REPLACES WHAT THE WIDENING COST.** `KillRewind` was extracted from
## `KillSystem` at US-0070 and the list above had to name the new file. That alone
## would let any system rewind by holding one — so the rule is restated as
## *ownership* rather than as a filename: exactly one class may construct it, and
## it is the one ADR-0010 names.
func test_only_the_kill_system_holds_the_kill_rewind() -> void:
	var holders: PackedStringArray = []
	var scanned := 0
	for root: String in ["res://scripts/core", "res://scripts/systems", "res://scripts/net"]:
		for path: String in SourceScanner.gd_files(root):
			scanned += 1
			if path.ends_with("kill_rewind.gd"):
				continue  # the definition, not a holder
			for row: Array in SourceScanner.code_lines(path):
				if String(row[1]).contains("KillRewind.new("):
					holders.append("%s:%d" % [path, int(row[0])])
	assert_gt(scanned, 2, "the scan found almost no files — the paths are stale")
	assert_gt(holders.size(), 0, "nothing holds a KillRewind at all — this guard checks nothing")
	var strangers: PackedStringArray = []
	for holder: String in holders:
		if not REWIND_OWNERS.has(holder.substr(0, holder.rfind(":"))):
			strangers.append(holder)
	assert_eq(
		strangers.size(),
		0,
		(
			"Something other than KillSystem holds a KillRewind. ADR-0010 allows two "
			+ "rewinding verbs and this is how a third would get one: "
			+ ", ".join(strangers)
		)
	)
