## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **THE PREY WARNING SAYS WHERE, AND MAY NEVER SAY WHO — ON THE WIRE.**
##
## `test_prey_warning_signal_arity.gd` guards the same rule one layer up, on the
## event bus. This file guards the layer that actually leaks: a field added to
## `NET-S2C-PREY-WARNING` reaches every client whether or not a widget draws it,
## and no amount of care in presentation can put it back.
##
## **A persona on this message would collapse the crowd from seventy-eight
## candidates to one, permanently and for free.** `ASM-0030`'s Compass lock is the
## only thing in the game that earns an identity — 1.6 s of held sight through a
## 25° cone — and it would have nothing left to earn.
##
## Why review misses it: `bearing` and `bucket` are already two fields, so adding
## `slot:u8` looks like completing a pattern rather than breaking a rule.
extends GutTest

const WIRE := "res://scripts/net/event_wire.gd"
const PROTOCOL := "res://docs/30_bible/NETWORK_PROTOCOL.md"
const RPC_NAME := "s2c_prey_warning"
const MESSAGE := "NET-S2C-PREY-WARNING"

## Anything naming, identifying or distinguishing a *person* rather than a
## direction. `peer` catches a raw id; `slot` catches the wire form, which is the
## one that would actually be added.
const IDENTIFYING: Array[String] = [
	"persona",
	"slot",
	"peer",
	"name",
	"identity",
	"colour",
	"color",
	"portrait",
	"tier",
]


## The RPC's declared parameter list, or "" if the function is absent.
func _rpc_parameters() -> String:
	for pair: Array in SourceScanner.code_lines(WIRE):
		var line: String = String(pair[1]).strip_edges()
		if line.begins_with("func " + RPC_NAME + "("):
			return line.substr(line.find("(") + 1, line.rfind(")") - line.find("(") - 1)
	return ""


func test_the_rpc_exists() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every assertion below is satisfied by a
	# message that does not exist, and this file would then report that the
	# anonymity rule holds over nothing at all.
	assert_ne(_rpc_parameters(), "", "%s is missing from event_wire.gd entirely" % RPC_NAME)


func test_the_rpc_names_nobody() -> void:
	var params := _rpc_parameters().to_lower()
	var offenders: PackedStringArray = []
	for word: String in IDENTIFYING:
		if params.contains(word):
			offenders.append(word)
	assert_eq(
		offenders.size(),
		0,
		(
			"%s gained an identifying parameter: %s.\n" % [RPC_NAME, ", ".join(offenders)]
			+ "The warning may say WHERE. It may never say WHO — GDD-03 §9.1, and it is\n"
			+ "the whole of what survives the 2026-08-26 amendment that made it directional.\n"
			+ "declared as: "
			+ _rpc_parameters()
		)
	)


func test_the_rpc_carries_exactly_two_fields() -> void:
	# A bearing and a bucket. A third field is the one this guard is really about,
	# and counting is what catches one whose name is innocent.
	var count := _rpc_parameters().split(",").size()
	assert_eq(
		count, 2, "%s declares %d fields; it may carry a bearing and a bucket" % [RPC_NAME, count]
	)


## The payload cell of the message's row in the protocol catalogue.
func _catalogue_payload() -> String:
	for line: String in SourceScanner.read(PROTOCOL).split("\n"):
		if not line.contains("`" + MESSAGE + "`"):
			continue
		var cells := line.split("|")
		if cells.size() >= 6:
			return String(cells[5]).strip_edges()
	return ""


func test_the_catalogue_row_agrees_with_the_code() -> void:
	# **THE DOCUMENT IS THE PART A DESIGNER READS**, so a row still promising a
	# directionless warning would be worse than no row: it is what stops anybody
	# checking (trap 14).
	var payload := _catalogue_payload().to_lower()
	assert_ne(payload, "", "%s has no row in the protocol catalogue" % MESSAGE)
	assert_true(
		payload.contains("bearing"), "the catalogue row does not name a bearing: " + payload
	)
	assert_true(payload.contains("bucket"), "the catalogue row does not name a bucket: " + payload)


func test_the_catalogue_row_names_nobody_either() -> void:
	var payload := _catalogue_payload().to_lower()
	var offenders: PackedStringArray = []
	for word: String in IDENTIFYING:
		if payload.contains(word):
			offenders.append(word)
	assert_eq(
		offenders.size(), 0, "the catalogue row leaks: %s\n%s" % [", ".join(offenders), payload]
	)


func test_it_goes_to_one_recipient() -> void:
	# **BROADCASTING IT WOULD BE A GLOBAL CARELESSNESS FEED** — every living player
	# told that somebody, somewhere, had gone loud. Working that out from a crowd
	# startling two streets away is the inference the game is made of, and
	# `rpc_id` versus `rpc` is the one character that decides it.
	assert_true(
		SourceScanner.code_contains(WIRE, RPC_NAME + ".rpc_id("),
		"the prey warning is not addressed to a single peer"
	)
	assert_false(
		SourceScanner.code_contains(WIRE, RPC_NAME + ".rpc("),
		"the prey warning is broadcast — never-do #12, as a kill feed for carelessness"
	)
