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

## Mutating entry points. Assignment to a bare property is caught separately.
const MUTATORS: Array[String] = ["GameState.replace(", "GameState.clear("]


func test_no_reader_calls_a_mutator() -> void:
	var violations: PackedStringArray = []
	for root: String in READERS:
		for path: String in SourceScanner.gd_files(root):
			for mutator: String in MUTATORS:
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
	var fields: Array[String] = ["phase", "local_peer_id", "roster"]
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
