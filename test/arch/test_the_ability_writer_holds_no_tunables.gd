## **THE `.tres` WRITER MAY NOT CARRY A NUMBER.** 2026-09-04.
##
## `tools/generate_default_tuning.gd` writes every section's resource from its own
## class's defaults, which are generated from `TUNABLES.md` — so the document is the
## only place a value can be changed. **The abilities were the exception**, because
## `AbilityData` is one class holding four abilities' fields and a class default can
## only be one of them: `duration` is 6 s of smoke for Cinderfall and 15 s of a false
## face for Second Face.
##
## **SO THE WRITER CARRIED A HAND-WRITTEN TABLE OF 45 NUMBERS, AND IT DRIFTED.**
## Running the documented command on 2026-09-04 reverted `TUN-CINDERFALL-THROW-RANGE`
## 0.0 → 8.0, undoing ADR-0013; dropped `TUN-CINDERFALL-DURATION` 6.0, set by the
## owner at the controls the day before; and dropped `effect_script` from both live
## abilities, which makes Cinderfall and Lunge do nothing. **The run printed
## success**, and the codegen README tells you to run it after every regeneration.
##
## `AbilityDefaults` is the fix and this is what stops it being undone. The wiring
## table may hold content and code — an id, a display key, a tell sound, the
## server-only effect script — and **may not hold anything `TuningIndex` knows the
## name of**, because a field written there wins over the generated value silently.
##
## Falsified by putting `"cooldown": 45.0` back into `ABILITY_WIRING`: this reddens
## and names the ability, the field and the tunable it shadows.
extends GutTest

const WRITER := "res://tools/generate_default_tuning.gd"

## Content and code, never tuning. Each is a fact about which ability this is or
## what runs it, and none of them has a `TUN-` id or a value anybody would balance.
const MAY_BE_HAND_WRITTEN := ["id", "display_key", "tell_sfx", "effect_script"]


func test_the_wiring_table_holds_no_tunable_field() -> void:
	var wiring := _wiring()
	assert_gt(wiring.size(), 0, "ABILITY_WIRING did not resolve — this test proves nothing")

	var tunable := _fields_with_a_tun_id()
	assert_gt(tunable.size(), 0, "no ability field resolved through TuningIndex")

	var offenders: PackedStringArray = []
	for ability: String in wiring:
		var abil_id := String(wiring[ability].get("id", ""))
		for field: String in wiring[ability]:
			if field in MAY_BE_HAND_WRITTEN:
				continue
			var key := "%s.%s" % [abil_id, field]
			if tunable.has(key):
				offenders.append(
					(
						"%s.%s shadows %s — delete it, the value comes from AbilityDefaults"
						% [ability, field, tunable[key]]
					)
				)
			else:
				offenders.append("%s.%s is neither wiring nor a tunable" % [ability, field])
	assert_eq(
		offenders.size(), 0, "the ability writer is carrying values again.\n" + "\n".join(offenders)
	)


func test_every_wired_ability_has_generated_values() -> void:
	# The other half: a wiring entry with no `AbilityDefaults` row writes an ability
	# whose every number is the class default — the inert zero, four times over.
	var missing: PackedStringArray = []
	for ability: String in _wiring():
		var values: Dictionary = AbilityDefaults.VALUES.get(ability, {})
		if values.is_empty():
			missing.append(ability)
	assert_eq(missing.size(), 0, "wired with no generated values: " + ", ".join(missing))


## `ABILITY_WIRING` read from the script's constant map rather than by parsing the
## source, so a reformat cannot defeat this and the test reads exactly what the
## writer reads.
func _wiring() -> Dictionary:
	var script: GDScript = load(WRITER)
	return script.get_script_constant_map().get("ABILITY_WIRING", {})


## `{ "ABIL-X.field": TUN- id }` for every ability field the tuning index names.
##
## **KEYED BY ABILITY AND FIELD, NOT BY FIELD ALONE.** All four abilities have a
## `cooldown`, so a map keyed on the field name holds whichever the index listed
## last — and the first falsification run reported a planted Cinderfall value as
## shadowing `TUN-WHISPERBOLT-COOLDOWN`. The guard fired correctly and named the
## wrong tunable, which is the instrument-wrong-in-a-plausible-direction this
## corpus keeps paying for.
func _fields_with_a_tun_id() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in TuningIndex.FIELD:
		var entry: Array = TuningIndex.FIELD[id]
		if entry.size() >= 2 and String(entry[0]).begins_with("ABIL-"):
			out["%s.%s" % [entry[0], entry[1]]] = String(id)
	return out
