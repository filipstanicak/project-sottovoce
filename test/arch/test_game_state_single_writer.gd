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


## **THE MUTATORS ARE READ OFF `GameState` RATHER THAN LISTED HERE, AND THEY ARE
## CLASSIFIED BY WHAT THEY WRITE.** Until 2026-09-13 this was a two-entry constant,
## and a third mutator (`adopt_match`, for `NET-S2C-MATCH-START`) would have joined
## the file without joining the guard. The first derivation used the return type —
## every reader answers a value, every mutator returns `void` — and the second
## agent's review broke it in one move: give `adopt_match` a `bool` to return, keep
## every write, and the guard silently drops it. A signature is a convention. **A
## write is a fact**: a function is a mutator if its body assigns a top-level `var`,
## or calls a function that does, to any depth. `clear()` writes nothing itself and
## reaches `replace` — the closure is what keeps it.
##
## Pure over the source text, so the counterexample is a test rather than a story.
static func _mutators_in(source: String) -> Array[String]:
	var fields := _fields_in(source)
	var bodies := _functions_in(source)
	var writers: Array[String] = []
	for name: String in bodies:
		for line: String in bodies[name]:
			if _assigns_one_of(line, fields):
				writers.append(name)
				break
	var grew := true
	while grew:
		grew = false
		for name: String in bodies:
			if writers.has(name):
				continue
			for line: String in bodies[name]:
				if _calls_one_of(line, writers):
					writers.append(name)
					grew = true
					break
	return writers


static func _mutators() -> Array[String]:
	var out: Array[String] = []
	for name: String in _mutators_in(SourceScanner.read(GAME_STATE)):
		out.append("GameState.%s(" % name)
	return out


## Every top-level `var` name, for the property check and for the write test.
static func _fields_in(source: String) -> Array[String]:
	var out: Array[String] = []
	for raw: String in source.split("\n"):
		var line := raw.get_slice("#", 0)
		if line.begins_with("var "):
			out.append(line.substr(4).split(":")[0].split("=")[0].strip_edges())
	return out


static func _fields() -> Array[String]:
	return _fields_in(SourceScanner.read(GAME_STATE))


## `{name: [body lines]}` for every top-level `func`, whatever it returns.
static func _functions_in(source: String) -> Dictionary:
	var out: Dictionary = {}
	var current := ""
	for raw: String in source.split("\n"):
		var line := raw.get_slice("#", 0).strip_edges(false, true)
		if line.begins_with("func ") or line.begins_with("static func "):
			var head := line.trim_prefix("static ").substr(5)
			current = head.substr(0, head.find("("))
			out[current] = []
		elif current != "" and (line.begins_with("\t") or line.begins_with(" ")):
			out[current].append(line.strip_edges())
		elif line != "":
			current = ""
	return out


## `field = x`, `field += x` and the rest — never `field == x`.
static func _assigns_one_of(line: String, fields: Array[String]) -> bool:
	for field: String in fields:
		if not line.begins_with(field):
			continue
		var rest := line.substr(field.length()).strip_edges(true, false)
		if rest.begins_with("=="):
			continue
		for op: String in ["=", "+=", "-=", "*=", "/="]:
			if rest.begins_with(op):
				return true
	return false


static func _calls_one_of(line: String, names: Array[String]) -> bool:
	for name: String in names:
		if line.contains(name + "("):
			return true
	return false


## PREMISE. The derivations above must at least find what has always been there.
func test_the_derivation_finds_the_known_members() -> void:
	var mutators := _mutators()
	var fields := _fields()
	for name: String in KNOWN_MUTATORS:
		assert_has(mutators, "GameState.%s(" % name, "the mutator scan lost %s" % name)
	for name: String in KNOWN_FIELDS:
		assert_has(fields, name, "the field scan lost %s" % name)


## **THE SECOND AGENT'S COUNTEREXAMPLE, AS A TEST.** A mutator that returns `bool`
## and writes exactly what the `void` one wrote must still be classified; a `void`
## function that writes nothing must not be — otherwise the classification was the
## signature wearing a property's name.
func test_a_mutator_is_known_by_its_writes_and_not_by_its_signature() -> void:
	var source := (
		"var match_seed: int = 0\n"
		+ "var match_known: bool = false\n"
		+ "func adopt_match(seed_value: int) -> bool:\n"
		+ "\tmatch_seed = seed_value\n"
		+ "\tmatch_known = true\n"
		+ "\treturn true\n"
		+ "func has_match() -> bool:\n"
		+ "\treturn match_known\n"
		+ "func announce() -> void:\n"
		+ "\tstate_replaced.emit()\n"
		+ "func compare() -> bool:\n"
		+ "\treturn match_seed == 0\n"
	)
	var mutators := _mutators_in(source)
	assert_has(
		mutators, "adopt_match", "a bool-returning mutator was dropped by the classification"
	)
	assert_does_not_have(mutators, "has_match", "a reader was classified as a mutator")
	assert_does_not_have(
		mutators, "announce", "a void function that writes nothing was called a mutator"
	)
	assert_does_not_have(mutators, "compare", "an == comparison was read as an assignment")


## `clear()` writes nothing itself; it is a mutator because it reaches one.
func test_a_function_that_calls_a_writer_is_a_writer() -> void:
	var source := (
		"var phase: int = 0\n"
		+ "func replace(new_phase: int) -> void:\n"
		+ "\tphase = new_phase\n"
		+ "func clear() -> int:\n"
		+ "\treplace(0)\n"
		+ "\treturn 0\n"
		+ "func reset_everything() -> void:\n"
		+ "\tclear()\n"
	)
	var mutators := _mutators_in(source)
	assert_has(mutators, "clear", "a caller of a writer was not classified")
	assert_has(mutators, "reset_everything", "the closure stopped one hop short")


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
