## **EVERY NUMBER IN `TUNABLES.md` IS THE NUMBER THE GAME SHIPS.** US-0060.
##
## CLAUDE.md calls `data/tuning/default/*.tres` "THE gameplay values" and
## `docs/50_tuning/TUNABLES.md` the document that owns them. **Nothing compared
## the two** — 288 tunables, and the only checks were `@export_range` bounds and
## §17's cross-field invariants, neither of which can see a value that is simply
## the wrong one.
##
## **IT WAS FOUND BY A ZERO.** `TUN-CINDERFALL-DURATION` is published at 4.0 s and
## the `duration` row is **absent from `cinderfall.tres`**, so `AbilityData`'s own
## default of 0.0 shipped from M0 — a cinder cloud that lasts one tick. Nothing
## errored, because Godot writes only the properties that differ from a script's
## defaults and a missing row is indistinguishable from a deliberate zero. It
## surfaced only when `SYS-KILL` became the first code to ask how long a cloud
## lives.
##
## **THE `@export_range` SWEEP CANNOT COVER ABILITIES, AND THAT IS WHY THEY WERE
## OMITTED FROM IT.** `AbilityData` is one class holding the union of four
## abilities' fields, so `duration` means 4 s of smoke for Cinderfall and 15 s of
## a false face for Second Face, and no single band is right for both. The
## document is the only place the per-ability value exists — so the document is
## what this compares against.
extends GutTest

## Rows that must be found and compared before this test means anything. The
## whole point is that a parser which silently matched nothing would pass every
## assertion below.
const MINIMUM_COVERAGE := 200

const DOC := "res://docs/50_tuning/TUNABLES.md"


func test_every_documented_value_is_the_shipped_value() -> void:
	var compared := 0
	var mismatches: PackedStringArray = []
	for row: Array in _documented_rows():
		var id: StringName = row[0]
		var documented: float = row[1]
		var shipped: Variant = _shipped(id)
		if shipped == null:
			continue
		compared += 1
		if not is_equal_approx(float(shipped), documented):
			mismatches.append("%s: document says %s, data ships %s" % [id, documented, shipped])
	gut.p("compared %d documented values against the shipped profile" % compared)
	assert_gte(compared, MINIMUM_COVERAGE, "the table parser found almost nothing — see the header")
	assert_eq(
		mismatches.size(),
		0,
		"TUNABLES.md and the shipped profile disagree.\n" + "\n".join(mismatches)
	)


func test_the_parser_can_actually_fail() -> void:
	# **THE COUNTERFACTUAL.** A comparison that always agreed would satisfy the
	# test above perfectly. `TUN-KILL-RANGE` is compared against a value it is not.
	var shipped: Variant = _shipped(&"TUN-KILL-RANGE")
	assert_not_null(shipped, "TUN-KILL-RANGE did not resolve — the resolver is broken")
	assert_false(
		is_equal_approx(float(shipped), 99.0), "the comparison cannot distinguish 2.5 from 99.0"
	)


func test_the_one_that_was_wrong_is_covered() -> void:
	# A named regression, because the general sweep above would go quiet again if
	# somebody removed the ability rows from the parser rather than from the data.
	var shipped: Variant = _shipped(&"TUN-CINDERFALL-DURATION")
	assert_not_null(shipped, "TUN-CINDERFALL-DURATION does not resolve through TuningIndex")
	assert_gt(float(shipped), 0.0, "a cinder cloud lasts zero seconds again")
	assert_gt(
		Tuning.ticks(&"TUN-CINDERFALL-DURATION"), 1, "the cloud's lifetime is one tick or less"
	)


## `[id, value]` for every row of the document whose ID `TuningIndex` knows.
##
## **THE VALUE IS THE FIRST PARSEABLE CELL AFTER THE ID**, which is what lets one
## parser read both table layouts: §5's is `ID | Value | Unit | Range | Rationale`
## and §16's scoring table inserts a `SCORE-` id column between the two. Taking a
## fixed column index would read the scoring section's ids as values, and taking
## the *last* number would read the low end of the Range column — `"2.0-3.2"`
## parses as 2.0, which is a wrong answer that looks like a right one.
func _documented_rows() -> Array:
	var out: Array = []
	for line: String in SourceScanner.read(DOC).split("\n"):
		if not line.begins_with("| `TUN-"):
			continue
		var cells := line.split("|")
		var id := StringName(cells[1].strip_edges().replace("`", ""))
		if not TuningIndex.FIELD.has(id):
			continue
		var value: Variant = _first_number(cells)
		if value != null:
			out.append([id, float(value)])
	return out


## The first cell after the ID that reads as a number or a bool, or null.
##
## **EMPHASIS IS STRIPPED, AND NOT DOING SO BLINDED THIS TEST TO THE ONE DRIFT IT
## EXISTS TO CATCH.** ADR-0018 wrote `TUN-STUN-SCORE`'s new value as `**200**` to
## mark the change, and `is_valid_float()` answers false for that — so this walked
## past the value, found no number in any later cell, and **dropped the row**. The
## generator's own `^[+-]?\d` match failed on the same two asterisks, so
## `combat_tuning.gd` kept the pre-ADR 100 and this test could not see it. Two
## independent readers of one column, defeated identically, and the guard written to
## catch the drift was the second casualty of it.
static func _first_number(cells: PackedStringArray) -> Variant:
	for i: int in range(2, cells.size()):
		var cell := cells[i].strip_edges().replace("*", "").replace("`", "").strip_edges()
		if cell == "true":
			return 1.0
		if cell == "false":
			return 0.0
		if cell.is_valid_float():
			return cell.to_float()
	return null


## The shipped value behind `id`, or null if it is not a number or a bool.
##
## Resolved through `TuningIndex.FIELD` rather than by name, so the mapping under
## test is the same one the game reads its constants through.
func _shipped(id: StringName) -> Variant:
	var entry: Array = TuningIndex.FIELD.get(id, [])
	if entry.size() < 2:
		return null
	var holder := _holder(String(entry[0]))
	if holder == null:
		return null
	var value: Variant = holder.get(StringName(entry[1]))
	if value is bool:
		return 1.0 if value else 0.0
	if value is float or value is int:
		return float(value)
	return null


func _holder(name: String) -> Resource:
	if name.begins_with("ABIL-"):
		return Tuning.profile.abilities.get(StringName(name)) as Resource
	if name.begins_with("PASV-"):
		return Tuning.profile.passives.get(StringName(name)) as Resource
	return Tuning.get(StringName(name)) as Resource
