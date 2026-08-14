## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **`SystemOrder.STAGES` IS TDD-01 §4'S DIAGRAM.** US-0027.
##
## The order is a design decision with three load-bearing boundaries — crowd
## before suspicion, suspicion before detection, kill/stun before contract — and
## each is argued in the document. The code that implements it is a list of ten
## names in another file.
##
## Why review misses this: both are individually plausible. A diagram with the
## stages in one order reads fine; a list in another order reads fine; and the
## consequence of them disagreeing is not an error but a rule computed against
## last tick's state, which looks like a tuning problem for as long as anyone
## cares to look.
##
## Parsed from the mermaid source, so the *document* is the authority and the
## code is what must follow.
extends GutTest

const CHAPTER := "res://docs/20_tdd/01_architecture.md"

## The diagram's label -> the stage name `SystemOrder` uses. Two of them differ
## because the diagram names what happens and the code names the stage: "Kill /
## Stun" is one stage, `combat`, and "Snapshot" is "build + send".
const LABEL_TO_STAGE: Dictionary = {
	"ingest inputs": &"ingest",
	"pawn movement": &"pawn",
	"crowd": &"crowd",
	"suspicion": &"suspicion",
	"detection": &"detection",
	"abilities": &"abilities",
	"kill / stun": &"combat",
	"contract": &"contract",
	"score": &"score",
	"snapshot": &"snapshot",
}


## The numbered stages of §4's flowchart, in the order the document numbers them.
func _documented_stages() -> Array:
	var text := FileAccess.get_file_as_string(CHAPTER)
	var re := RegEx.create_from_string('\\["(\\d+)\\. ([^<"]+)')
	var found: Array = []
	for m: RegExMatch in re.search_all(text):
		found.append([int(m.get_string(1)), m.get_string(2).strip_edges().to_lower()])
	found.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return found


func test_the_diagram_was_actually_read() -> void:
	# Guards the guard. A renamed chapter or a reworked diagram would make every
	# assertion below pass over nothing — the failure shape this project has now
	# shipped four times.
	assert_eq(
		_documented_stages().size(),
		SystemOrder.STAGES.size(),
		"TDD-01 §4's diagram no longer yields ten numbered stages — the parse broke"
	)


func test_the_declared_order_is_the_documented_order() -> void:
	var mismatches: PackedStringArray = []
	var documented := _documented_stages()
	for i: int in documented.size():
		var label: String = documented[i][1]
		var expected: StringName = LABEL_TO_STAGE.get(label, &"?")
		if i >= SystemOrder.STAGES.size():
			break
		if expected != SystemOrder.STAGES[i]:
			mismatches.append(
				(
					"position %d: the diagram says `%s`, SystemOrder says `%s`"
					% [i + 1, label, SystemOrder.STAGES[i]]
				)
			)
	assert_eq(
		mismatches.size(),
		0,
		(
			"The tick order in code is not the order TDD-01 §4 specifies.\n"
			+ "Three boundaries carry an argument: crowd before suspicion, suspicion\n"
			+ "before detection, kill/stun before contract. Getting one wrong is not an\n"
			+ "error — it is a rule computed against last tick's state.\n"
			+ "\n".join(mismatches)
		)
	)


func test_every_documented_label_is_mapped() -> void:
	# A label the map does not know becomes `?`, which would fail the comparison
	# above with a confusing message. Fail here instead, where the cause is named.
	for stage: Array in _documented_stages():
		assert_true(
			LABEL_TO_STAGE.has(stage[1]), "the diagram has an unmapped stage: `%s`" % stage[1]
		)


func test_the_check_can_actually_fail() -> void:
	# Falsification against a planted line, so the regex is proven to see what it
	# claims rather than to find nothing everywhere.
	var re := RegEx.create_from_string('\\["(\\d+)\\. ([^<"]+)')
	var planted := 'A["4. Suspicion<br/>needs final positions"] --> B'
	var m := re.search(planted)
	assert_not_null(m, "the stage regex no longer matches a diagram node")
	assert_eq(m.get_string(1), "4")
	assert_eq(m.get_string(2).strip_edges().to_lower(), "suspicion")
