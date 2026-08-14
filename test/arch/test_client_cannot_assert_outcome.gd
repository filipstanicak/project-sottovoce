## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **NO CLIENT MESSAGE CARRIES AN OUTCOME.** TDD-04 §2.1 and §12,
## NETWORK_PROTOCOL §2.1.
##
## A client sends *intent*, never *result*. `NET-C2S-INPUT` says "I am holding
## the kill button"; there is no message anywhere by which a client says "I
## killed player 3". That single property is what lets SCOPE_FENCE OUT #9 defer
## every form of anti-cheat beyond server authority — so it is worth a guard that
## reads the catalogue rather than trusting that nobody will add a convenient
## field.
##
## Why review misses this: the field that breaks it always arrives for a good
## reason. `victim_id` in an input payload saves a lookup. `damage` saves a
## calculation. Each is one column in a table nobody re-reads, and the property
## it destroys is stated three documents away.
##
## Parsed from the corpus, not from code, because the catalogue is where a
## message is *designed*. A field caught here has not been implemented yet.
extends GutTest

const CATALOGUE := "res://docs/30_bible/NETWORK_PROTOCOL.md"

## Words that name a thing that has happened, rather than a thing being asked
## for. A payload field containing one of these is a client stating a result.
const OUTCOME_WORDS: Array[String] = [
	"kill",
	"killed",
	"victim",
	"damage",
	"death",
	"died",
	"hit",
	"score",
	"points",
	"suspicion",
	"tier",
	"result",
	"position",
	"velocity",
	"detected",
]


## Every C2S row in the catalogue: [id, payload].
func _c2s_rows() -> Array:
	var text := FileAccess.get_file_as_string(CATALOGUE)
	var out: Array = []
	for line: String in text.split("\n"):
		if not line.begins_with("| `NET-C2S-"):
			continue
		var cells := line.split("|")
		if cells.size() < 6:
			continue
		out.append([cells[1].strip_edges(), cells[5].strip_edges()])
	return out


func test_the_catalogue_was_actually_read() -> void:
	# Guards the guard. A renamed document or a changed table shape would make
	# every assertion below pass over nothing at all — the exact failure this
	# project has now hit three times.
	assert_gt(_c2s_rows().size(), 5, "found almost no C2S rows — the catalogue moved or changed")


func test_no_c2s_payload_names_an_outcome() -> void:
	var offenders: PackedStringArray = []
	for row: Array in _c2s_rows():
		var payload: String = String(row[1]).to_lower()
		for word: String in OUTCOME_WORDS:
			if payload.contains(word):
				offenders.append("%s carries `%s` in %s" % [row[0], word, row[1]])
	offenders.sort()

	assert_eq(
		offenders.size(),
		0,
		(
			"A client-to-server message carries an outcome.\n"
			+ "A client may send intent and nothing else: NET-C2S-INPUT says 'I am\n"
			+ "holding the kill button', never 'I killed player 3'. This property is\n"
			+ "what lets SCOPE_FENCE OUT #9 defer anti-cheat to server authority.\n"
			+ "\n".join(offenders)
		)
	)


func test_the_forbidden_messages_have_no_row_at_all() -> void:
	# The stronger half. §2.1 names five messages while explaining that they do
	# not exist; if one ever acquired a table row, it would exist.
	var ids: PackedStringArray = []
	for row: Array in _c2s_rows():
		ids.append(String(row[0]).replace("`", ""))
	for forbidden: StringName in Messages.FORBIDDEN:
		assert_false(
			ids.has(String(forbidden)), "%s has acquired a row in the catalogue" % forbidden
		)


func test_the_check_can_actually_fail() -> void:
	# Falsification against a planted row, so the parser is proven to see what it
	# claims to see rather than to find nothing everywhere.
	var planted := (
		"| `NET-C2S-INPUT` | S | Unrel | 60 Hz " + "| `seq:u16`, `victim:u8` | Sender owns a pawn |"
	)
	var cells := planted.split("|")
	assert_eq(cells[1].strip_edges(), "`NET-C2S-INPUT`", "the row parser lost the id column")
	assert_true(
		cells[5].strip_edges().to_lower().contains("victim"),
		"the row parser lost the payload column — the scan would pass over anything"
	)
