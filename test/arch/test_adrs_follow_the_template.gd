## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY ADR OPENS WITH DECISION_LOG §2.2's FRONTMATTER, KEY FOR KEY.** The template
## says *"New ADRs use this shape exactly"*, and from ADR-0012 on eleven of them left
## out `supersedes:` without anybody deciding they should. The review of #240 found it
## when four more were about to follow ADR-0017's shape rather than the template's.
##
## **THE KEYS ARE READ OFF THE TEMPLATE, NOT LISTED HERE**, so amending §2.2 moves this
## guard with it rather than leaving a second copy of the shape to drift. One extra key
## is allowed and only where it is true: `superseded_by`, on an ADR whose status is
## `superseded` (ADR-0001). A `supersedes:` naming an ADR requires that ADR to say it
## was superseded.
extends GutTest

const TEMPLATE := "res://docs/00_meta/DECISION_LOG.md"
const ADR_DIR := "res://docs/00_meta/adr/"
const OPENING := "```markdown\n---\n"


## The template's frontmatter keys, in order, from the fenced block under §2.2. **PURE.**
static func template_keys(log: String) -> PackedStringArray:
	var start := log.find("### 2.2 ADR template")
	var fence := log.find(OPENING, start)
	if start < 0 or fence < 0:
		return PackedStringArray()
	var body := log.substr(fence + OPENING.length())
	return _keys(body.substr(0, body.find("\n---\n")))


## `{key: value}` of a document's opening frontmatter, in order. **PURE.**
static func frontmatter(text: String) -> Dictionary:
	var out := {}
	var clean := text.replace("\r\n", "\n")
	if not clean.begins_with("---\n"):
		return out
	var block := clean.substr(4, clean.find("\n---\n", 4) - 4)
	for line: String in block.split("\n"):
		var colon := line.find(":")
		if colon > 0 and not line.begins_with(" "):
			out[line.substr(0, colon)] = line.substr(colon + 1).strip_edges()
	return out


static func _keys(block: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in block.split("\n"):
		var colon := line.find(":")
		if colon > 0:
			out.append(line.substr(0, colon))
	return out


## Every way one ADR's frontmatter departs from `keys`, as readable lines. **PURE.**
static func departures(
	name: String, front: Dictionary, keys: PackedStringArray
) -> PackedStringArray:
	var out := PackedStringArray()
	var have := PackedStringArray(front.keys())
	var extra := PackedStringArray()
	for key: String in have:
		if not keys.has(key):
			extra.append(key)
	var ordered := PackedStringArray()
	for key: String in have:
		if keys.has(key):
			ordered.append(key)
	if ordered != keys:
		out.append("%s: keys %s, the template has %s" % [name, ordered, keys])
	for key: String in extra:
		if not (key == "superseded_by" and front.get("status") == "superseded"):
			out.append("%s: `%s` is not in the template" % [name, key])
	var sup := str(front.get("supersedes", ""))
	if sup != "none" and not RegEx.create_from_string("^ADR-\\d{4}$").search(sup):
		out.append("%s: supersedes is '%s', not an ADR id or none" % [name, sup])
	return out


func _adrs() -> Dictionary:
	var out := {}
	for file: String in DirAccess.get_files_at(ADR_DIR):
		if file.begins_with("ADR-") and file.ends_with(".md"):
			out[file] = frontmatter(SourceScanner.read(ADR_DIR + file))
	return out


func test_the_template_and_the_adrs_were_actually_read() -> void:
	# **THE PREMISE.** An empty key list or an empty folder passes everything below.
	assert_eq(
		template_keys(SourceScanner.read(TEMPLATE)).size(), 8, "the §2.2 template was not read"
	)
	assert_gte(_adrs().size(), 24, "fewer ADRs were read than exist")


func test_every_adr_carries_the_template_frontmatter() -> void:
	var keys := template_keys(SourceScanner.read(TEMPLATE))
	var adrs := _adrs()
	var problems := PackedStringArray()
	for file: String in adrs:
		problems.append_array(departures(file, adrs[file], keys))
	assert_eq(problems.size(), 0, "ADRs depart from DECISION_LOG §2.2:\n  " + "\n  ".join(problems))


func test_a_superseded_adr_says_so() -> void:
	var adrs := _adrs()
	var by_id := {}
	for file: String in adrs:
		by_id[str(adrs[file].get("id", ""))] = adrs[file]
	for file: String in adrs:
		var sup := str(adrs[file].get("supersedes", "none"))
		if sup != "none":
			assert_true(by_id.has(sup), "%s supersedes %s, which does not exist" % [file, sup])
			var status := str(by_id.get(sup, {}).get("status", ""))
			assert_eq(
				status, "superseded", "%s supersedes %s, whose status is %s" % [file, sup, status]
			)


func test_the_check_can_actually_fail() -> void:
	var keys := PackedStringArray(["id", "status", "supersedes"])
	var missing := departures("A", frontmatter("---\nid: ADR-0099\nstatus: accepted\n---\n"), keys)
	assert_true(
		"\n".join(missing).contains("the template has"),
		"a missing supersedes was not reported: %s" % [missing]
	)
	var stray := departures(
		"B",
		frontmatter("---\nid: X\nstatus: accepted\nsupersedes: none\nsuperseded_by: Y\n---\n"),
		keys
	)
	assert_true("\n".join(stray).contains("superseded_by"), "superseded_by on a live ADR passed")
	var bad := departures(
		"C", frontmatter("---\nid: X\nstatus: accepted\nsupersedes: ASM-0030\n---\n"), keys
	)
	assert_true("\n".join(bad).contains("not an ADR id"), "a non-ADR supersedes passed")
	var fine := "---\nid: X\nstatus: superseded\nsupersedes: none\nsuperseded_by: ADR-0011\n---\n"
	assert_eq(
		departures("D", frontmatter(fine), keys).size(), 0, "a correct superseded ADR was refused"
	)
