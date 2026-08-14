## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Signal names are PAST-TENSE FACTS, everywhere in the codebase.
##
## `contract_assigned`, never `on_contract`, `assign_contract` or
## `contract_changed_signal`.
##
## Why review misses this: `on_contract` reads fine in isolation. The cost shows
## up later — an imperative name invites a listener to treat the signal as a
## command and do the work the emitter should have done, which is how a one-way
## bus quietly becomes bidirectional.
extends GutTest

const ROOTS: Array[String] = [
	"res://scripts/presentation",
	"res://scripts/systems",
	"res://scripts/net",
	"res://scripts/core",
	"res://scripts/autoload",
	"res://scripts/pawn",
	"res://scripts/mirrors",
	"res://scripts/server",
]

## Prefixes and suffixes that mark a name as a handler or a command, not a fact.
const FORBIDDEN_PREFIXES: Array[String] = ["on_", "do_", "handle_", "request_"]
const FORBIDDEN_SUFFIXES: Array[String] = ["_signal", "_event", "_callback"]

## Past-tense endings, plus the irregular forms actually used in the catalogue.
const PAST_TENSE_ENDINGS: Array[String] = ["ed", "en"]
##
## `peer_left` is the past tense of *leave*, and English does not spell it with
## an `-ed`. Renaming it to satisfy the heuristic would produce `peer_departed`,
## which is worse prose in service of a suffix — the rule is "past-tense fact",
## and this is one.
const ALLOWED_IRREGULARS: Array[String] = ["caption", "peer_left"]


func _signals() -> Array:
	var out: Array = []
	for root: String in ROOTS:
		for path: String in SourceScanner.gd_files(root):
			for pair: Array in SourceScanner.code_lines(path):
				var line: String = String(pair[1]).strip_edges()
				if not line.begins_with("signal "):
					continue
				var name := line.substr(7).split("(")[0].strip_edges()
				out.append([path, int(pair[0]), name])
	return out


func test_signals_exist_to_be_checked() -> void:
	# Guards the guard: an empty scan would make every assertion below vacuous.
	assert_gt(_signals().size(), 10, "found almost no signals — the scan is broken")


func test_no_signal_is_named_like_a_handler_or_a_command() -> void:
	var offenders: PackedStringArray = []
	for s: Array in _signals():
		var name: String = s[2]
		for p: String in FORBIDDEN_PREFIXES:
			if name.begins_with(p):
				offenders.append("%s:%d `%s` starts with '%s'" % [s[0], s[1], name, p])
		for suffix: String in FORBIDDEN_SUFFIXES:
			if name.ends_with(suffix):
				offenders.append("%s:%d `%s` ends with '%s'" % [s[0], s[1], name, suffix])
	offenders.sort()
	assert_eq(
		offenders.size(),
		0,
		(
			"A signal is named like a handler or a command. Signals are facts:\n"
			+ "name what HAPPENED, not what someone should do about it.\n"
			+ "\n".join(offenders)
		)
	)


func test_every_signal_name_is_past_tense() -> void:
	var offenders: PackedStringArray = []
	for s: Array in _signals():
		var name: String = s[2]
		if ALLOWED_IRREGULARS.has(name):
			continue
		var ok := false
		for ending: String in PAST_TENSE_ENDINGS:
			if name.ends_with(ending):
				ok = true
		if not ok:
			offenders.append("%s:%d `%s` is not past tense" % [s[0], s[1], name])
	offenders.sort()
	assert_eq(
		offenders.size(),
		0,
		(
			"A signal name is not a past-tense fact.\n"
			+ "If it is a genuine irregular, add it to ALLOWED_IRREGULARS with a reason.\n"
			+ "\n".join(offenders)
		)
	)
