## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## ONLY `scripts/net/` WRITES TO GameState. Everything else reads.
##
## Why review misses this: `GameState.phase = Phase.FINAL` in a system reads as
## perfectly ordinary code, and it works. The cost arrives later — with two
## writers, "what phase are we in" has two answers depending on when you ask, and
## the symptom is a HUD that disagrees with the server. The never-do list calls
## that worse than no HUD at all, precisely because the player trusts it.
##
## The one-writer rule is a convention nothing in GDScript enforces, so it is
## enforced here or not at all.
extends GutTest

## Every layer except the one allowed to write.
const READERS: Array[String] = [
	"res://scripts/core",
	"res://scripts/systems",
	"res://scripts/pawn",
	"res://scripts/mirrors",
	"res://scripts/presentation",
	"res://scripts/server",
	"res://scripts/autoload",
]

const GAME_STATE := "res://scripts/autoload/game_state.gd"

## Members the derivation below MUST find. A regex that matches nothing would
## make both checks vacuous, which is trap 3; these two mutators and these three
## fields have existed since M0 and are the floor the premise is asserted against.
const KNOWN_MUTATORS: Array[String] = ["replace", "clear"]
const KNOWN_FIELDS: Array[String] = ["phase", "local_peer_id", "roster"]


## **THE MUTATORS ARE READ OFF `GameState` RATHER THAN LISTED HERE.** Until
## 2026-09-13 this was a two-entry constant, and a third mutator (`adopt_match`,
## for `NET-S2C-MATCH-START`) would have joined the file without joining the
## guard — a list that goes stale in silence, which is the shape of every
## drift in this corpus. The structural signal is the return type: every
## reader on `GameState` answers a value and every mutator returns `void`.
static func _mutators() -> Array[String]:
	var out: Array[String] = []
	for pair: Array in SourceScanner.code_lines(GAME_STATE):
		var code: String = String(pair[1]).strip_edges(false, true)
		if code.begins_with("func ") and code.ends_with("-> void:"):
			out.append("GameState.%s(" % code.substr(5, code.find("(") - 5))
	return out


## Every top-level `var` on `GameState`, for the same reason.
static func _fields() -> Array[String]:
	var out: Array[String] = []
	for pair: Array in SourceScanner.code_lines(GAME_STATE):
		var line: String = String(pair[1])
		if line.begins_with("var "):
			out.append(line.substr(4).split(":")[0].split("=")[0].strip_edges())
	return out


## PREMISE. The derivations above must at least find what has always been there.
func test_the_derivation_finds_the_known_members() -> void:
	var mutators := _mutators()
	var fields := _fields()
	for name: String in KNOWN_MUTATORS:
		assert_has(mutators, "GameState.%s(" % name, "the mutator scan lost %s" % name)
	for name: String in KNOWN_FIELDS:
		assert_has(fields, name, "the field scan lost %s" % name)


func test_no_reader_calls_a_mutator() -> void:
	var violations: PackedStringArray = []
	for root: String in READERS:
		for path: String in SourceScanner.gd_files(root):
			for mutator: String in _mutators():
				for hit: String in SourceScanner.find(path, mutator):
					violations.append("%s calls %s)" % [hit, mutator])
	violations.sort()
	assert_eq(
		violations.size(),
		0,
		(
			"Something outside scripts/net/ mutated GameState.\n"
			+ "It is a mirror: Net writes, everyone else reads.\n"
			+ "\n".join(violations)
		)
	)


func test_no_reader_assigns_to_a_property() -> void:
	# The subtler half. `GameState.phase = x` bypasses `replace()` entirely and
	# leaves the object in a state no single update ever produced.
	var fields := _fields()
	var violations: PackedStringArray = []
	for root: String in READERS:
		for path: String in SourceScanner.gd_files(root):
			for pair: Array in SourceScanner.code_lines(path):
				var line: String = String(pair[1])
				for field: String in fields:
					if line.contains("GameState.%s =" % field):
						violations.append("%s:%d assigns GameState.%s" % [path, pair[0], field])
	violations.sort()
	assert_eq(
		violations.size(),
		0,
		(
			"Something assigned a GameState field directly.\n"
			+ "Use replace(), which cannot leave a half-applied update.\n"
			+ "\n".join(violations)
		)
	)


func test_the_scan_covers_real_files() -> void:
	# Guards the guard: an empty file list would make both checks vacuous.
	var total := 0
	for root: String in READERS:
		total += SourceScanner.gd_files(root).size()
	assert_gt(total, 5, "the reader scan found almost no files")
