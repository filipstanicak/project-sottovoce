## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY TABLE IN DATA_SCHEMA §3 IS ITS TUNING RESOURCE**, field for field: the
## same names, the same types, the same `@export_range` band and the same default.
##
## **FOUND 2026-09-29, AFTER A REVIEW CORRECTED ONE ROW AND FOUND THE REST.** The
## §3 tables were written by hand at M0 and never re-read. Regenerated from the
## scripts, thirteen of fourteen blocks were wrong: `MovementTuning` left out 21
## fields, `NetTuning` named five that do not exist, `CompassTuning` still said the
## prey warning gives no direction, `CameraTuning` listed the retired `fov_jog`, and
## `PerfTuning` had no section at all. TUNABLES is guarded against the shipped
## profile (`test_tunables_match_the_document.gd`); this page was guarded by nothing,
## so it drifted a little every time a tunable moved.
##
## **COMPARED AS VALUES, NOT AS TEXT.** `100` and `100.0` are one default, and a
## range written with a Unicode minus is the same band as one written with a hyphen.
## A string match would fail on formatting and pass nothing it should not.
extends GutTest

const DOC := "res://docs/30_bible/DATA_SCHEMA.md"
const TUNING := "res://scripts/core/tuning/"
const PROFILE := "res://scripts/core/tuning/tuning_profile.gd"

const HEADING := "(?m)^### 3\\.\\d+ `(\\w+)`"
const ROW := "(?m)^\\| `([a-z_0-9]+)` \\| (\\w+) \\| ([^|]+) \\| ([^|]+) \\|$"
const EXPORT := (
	"(?m)^@export(?:_range\\(([-\\d.]+),\\s*([-\\d.]+)[^)]*\\))?"
	+ "\\s+var\\s+(\\w+):\\s*(\\w+)\\s*=\\s*([-\\w.]+)\\s*$"
)
const SECTION := "(?m)^@export var \\w+: (\\w+) = \\w+\\.new\\(\\)"

## A table with one field right and four wrong, for the falsification.
const PLANTED_DOC := (
	"\n## 3. Sub-resources\n\n### 3.1 `PlantTuning`\n\n"
	+ "| Field | Type | Range | Default |\n|---|---|---|---|\n"
	+ "| `good` | float | 1–2 | 1.5 |\n"
	+ "| `wrong_default` | float | — | 3 |\n"
	+ "| `wrong_band` | float | 0–5 | 1 |\n"
	+ "| `wrong_type` | int | — | 2 |\n"
	+ "| `stale` | float | — | 9 |\n\n## 4. Next\n"
)
const PLANTED_SRC := (
	"@export_range(1.0, 2.0, 0.1) var good: float = 1.5\n"
	+ "@export var wrong_default: float = 4.0\n"
	+ "@export_range(0.0, 6.0, 0.1) var wrong_band: float = 1.0\n"
	+ "@export var wrong_type: float = 2.0\n"
	+ "@export var unlisted: bool = true\n"
)


## `{class: {field: [type, band, default]}}` for every table under `## 3.`, values
## canonical. **PURE**, so the planted text below goes through the same code.
static func tables(doc: String) -> Dictionary:
	# **A LINE START, NOT A SUBSTRING**: every `### 3.x` heading contains `## 3.`.
	var start := doc.find("\n## 3.")
	var stop := doc.find("\n## 4.", start)
	var body := doc.substr(start, stop - start if stop > start else -1)
	var out := {}
	var heads := RegEx.create_from_string(HEADING).search_all(body)
	for i: int in heads.size():
		var from := heads[i].get_end()
		var to := heads[i + 1].get_start() if i + 1 < heads.size() else body.length()
		var fields := {}
		for row: RegExMatch in RegEx.create_from_string(ROW).search_all(
			body.substr(from, to - from)
		):
			fields[row.get_string(1)] = [
				row.get_string(2), _band(row.get_string(3)), _value(row.get_string(4))
			]
		out[heads[i].get_string(1)] = fields
	return out


## `{field: [type, band, default]}` for a resource script's source text. **PURE.**
static func exports(src: String) -> Dictionary:
	var out := {}
	for m: RegExMatch in RegEx.create_from_string(EXPORT).search_all(src):
		var band := "—"
		if not m.get_string(1).is_empty():
			band = "%s..%s" % [_value(m.get_string(1)), _value(m.get_string(2))]
		out[m.get_string(3)] = [m.get_string(4), band, _value(m.get_string(5))]
	return out


## Every disagreement between one table and one resource, as readable lines.
static func mismatches(owner: String, table: Dictionary, resource: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for field: String in resource:
		if not table.has(field):
			out.append("%s.%s: in the resource, missing from the table" % [owner, field])
			continue
		var labels := ["type", "range", "default"]
		for i: int in 3:
			if str(table[field][i]) != str(resource[field][i]):
				out.append(
					(
						"%s.%s: %s is %s in the table and %s in the resource"
						% [owner, field, labels[i], table[field][i], resource[field][i]]
					)
				)
	for field: String in table:
		if not resource.has(field):
			out.append("%s.%s: in the table, no such field in the resource" % [owner, field])
	return out


## `3`, `3.0` and `3.00` are one value; a Unicode minus is a minus.
static func _value(text: String) -> String:
	var v := text.strip_edges().replace("−", "-").replace("*", "")
	if v == "true" or v == "false" or v == "—":
		return v
	return str(float(v))


static func _band(text: String) -> String:
	var v := text.strip_edges().replace("−", "-")
	if v == "—":
		return v
	var ends := v.split("–")
	return "%s..%s" % [_value(ends[0]), _value(ends[1])] if ends.size() == 2 else v


## `UiAudioTuning` -> `res://scripts/core/tuning/ui_audio_tuning.gd`.
static func script_of(owner: String) -> String:
	return TUNING + owner.to_snake_case() + ".gd"


func _doc_tables() -> Dictionary:
	return tables(SourceScanner.read(DOC))


func test_the_schema_was_actually_read() -> void:
	# **THE PREMISE.** A scan that found nothing would pass every assertion below.
	var found := _doc_tables()
	assert_gte(found.size(), 14, "fewer than fourteen §3 tables were found")
	var rows := 0
	for owner: String in found:
		rows += (found[owner] as Dictionary).size()
	assert_gt(rows, 200, "the §3 tables were found but hardly any rows in them")


func test_every_profile_section_has_a_table() -> void:
	# `PerfTuning` had no section at all until 2026-09-29: the profile is the list.
	var found := _doc_tables()
	var src := SourceScanner.read(PROFILE)
	var sections := RegEx.create_from_string(SECTION).search_all(src)
	assert_gte(sections.size(), 14, "the profile scan found fewer sections than exist")
	for m: RegExMatch in sections:
		assert_true(
			found.has(m.get_string(1)), "%s has no table in DATA_SCHEMA §3" % m.get_string(1)
		)


func test_every_table_is_its_resource() -> void:
	var problems := PackedStringArray()
	var found := _doc_tables()
	for owner: String in found:
		var path := script_of(owner)
		if not FileAccess.file_exists(path):
			problems.append("%s: no script at %s" % [owner, path])
			continue
		problems.append_array(mismatches(owner, found[owner], exports(SourceScanner.read(path))))
	assert_eq(
		problems.size(),
		0,
		"DATA_SCHEMA §3 disagrees with the resources it documents:\n  " + "\n  ".join(problems)
	)


func test_the_check_can_actually_fail() -> void:
	var table: Dictionary = tables(PLANTED_DOC)["PlantTuning"]
	var found := mismatches("PlantTuning", table, exports(PLANTED_SRC))
	var text := "\n".join(found)
	for expected: String in [
		"wrong_default: default",
		"wrong_band: range",
		"wrong_type: type",
		"stale: in the table",
		"unlisted: in the resource",
	]:
		assert_true(
			text.contains(expected), "the planted '%s' was not reported:\n%s" % [expected, text]
		)
	assert_false(text.contains("good"), "a field that agrees was reported:\n" + text)


func test_formatting_is_not_a_difference() -> void:
	assert_eq(_value("100"), _value("100.0"), "100 and 100.0 read as two defaults")
	assert_eq(_band("−100–0"), "%s..%s" % [_value("-100.0"), _value("0.0")], "a Unicode minus")
