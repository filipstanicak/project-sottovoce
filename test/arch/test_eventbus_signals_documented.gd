## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Every EventBus signal is documented, and matches the catalogue in
## SIGNAL_AND_EVENT_BUS.md §3 in BOTH DIRECTIONS.
##
## Why review misses this: an undocumented signal works perfectly. What it costs
## is later — a widget author cannot tell what the payload means or when it
## fires, so they subscribe and guess, and the guess is wrong in the one case
## that matters. A signal in the catalogue with no declaration is worse still:
## the document promises a channel that does not exist.
extends GutTest

const BUS := "res://scripts/presentation/event_bus.gd"
const CATALOGUE := "res://docs/30_bible/SIGNAL_AND_EVENT_BUS.md"


func _declared() -> Array:
	var out: Array = []
	var lines := SourceScanner.read(BUS).split("\n")
	for i: int in lines.size():
		var line := lines[i].strip_edges()
		if not line.begins_with("signal "):
			continue
		out.append([line.substr(7).split("(")[0].strip_edges(), i])
	return out


func test_every_signal_has_a_docstring_ending_in_its_evt_id() -> void:
	# The EVT- ID is the documentation identity. Requiring it as the LAST line
	# means a reader who greps the ID lands on the declaration, and a signal
	# added without one is obvious rather than merely undocumented.
	var lines := SourceScanner.read(BUS).split("\n")
	var offenders: PackedStringArray = []
	for entry: Array in _declared():
		var idx: int = entry[1]
		var above := lines[idx - 1].strip_edges() if idx > 0 else ""
		if not (above.begins_with("## EVT-") and above.length() > 7):
			offenders.append("`%s` (line %d) — last doc line is: %s" % [entry[0], idx + 1, above])
	assert_eq(
		offenders.size(),
		0,
		(
			"An EventBus signal has no EVT- ID as the last line of its docstring.\n"
			+ "\n".join(offenders)
		)
	)


func test_every_declared_signal_is_in_the_catalogue() -> void:
	var doc := SourceScanner.read(CATALOGUE)
	var missing: PackedStringArray = []
	for entry: Array in _declared():
		if not doc.contains("`" + String(entry[0]) + "("):
			missing.append(String(entry[0]))
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		(
			"A signal exists in code but not in SIGNAL_AND_EVENT_BUS.md §3.\n"
			+ "A channel nobody documented is a channel nobody can consume correctly.\n"
			+ "\n".join(missing)
		)
	)


func test_every_catalogued_signal_is_declared() -> void:
	# The more dangerous direction: the document promises a channel that does not
	# exist, and a widget author writes a listener that is never called.
	var doc := SourceScanner.read(CATALOGUE)
	var declared: Dictionary = {}
	for entry: Array in _declared():
		declared[entry[0]] = true

	var re := RegEx.create_from_string("\\| `([a-z_]+)\\(")
	var missing: PackedStringArray = []
	for m: RegExMatch in re.search_all(doc):
		var name := m.get_string(1)
		if not declared.has(name):
			missing.append(name)
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		(
			"SIGNAL_AND_EVENT_BUS.md §3 catalogues a signal the EventBus does not declare.\n"
			+ "\n".join(missing)
		)
	)


func test_the_catalogue_scan_found_something() -> void:
	# Guards the guard. If the regex stopped matching the table, the check above
	# would pass over an empty set and report success.
	var re := RegEx.create_from_string("\\| `([a-z_]+)\\(")
	assert_gt(
		re.search_all(SourceScanner.read(CATALOGUE)).size(),
		10,
		"the catalogue scan matched almost nothing — the table format changed"
	)
