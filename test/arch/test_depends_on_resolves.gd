## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY `depends_on` IN THE CORPUS NAMES A DOCUMENT THAT EXISTS.**
##
## Every document under `docs/` opens with frontmatter carrying its own `id:` and
## the `depends_on:` list that CLAUDE.md tells a fresh session to follow — *"read
## the `depends_on` chain of what you need"*. A link in that chain that resolves to
## nothing is a reader sent to a document that is not there, and it looks exactly
## like one that is: an id is an id.
##
## **MEASURED 2026-09-24: FIVE, IN FOUR FILES**, each a plausible short form of a
## real id — `GDD-03-SOCIAL` for `GDD-03-SOCIAL-STEALTH`, `BIBLE-ANIMATION` for
## `BIBLE-ANIMATION-SPEC`, `BIBLE-NAMING` for `BIBLE-NAMING-IDS`,
## `BIBLE-NETWORK-PROTOCOL` for `BIBLE-NET-PROTOCOL`, `GDD-02-PLAYER-CONTROLLER`
## for `GDD-02-PLAYER`. Two of them were written the day this guard was.
##
## **AND THE FIRST COUNT OF THEM WAS WRONG BY A FACTOR OF EIGHT, WHICH IS WHY THE
## MATCH HERE IS EXACT.** The report that raised this said *"`GDD-03-SOCIAL` is used
## in 34 files"* — a `grep` for the short form, which also matched every correct
## `GDD-03-SOCIAL-STEALTH`. The real number was one. A prefix match is the same
## instrument, and it would have passed the very defect it was written for;
## `test_a_prefix_of_a_real_id_is_still_dangling` holds that line.
extends GutTest

const ROOT := "res://docs"

## A document with one real dependency and one that is nowhere, for the falsification.
const PLANTED := "---\nid: US-9999\ndepends_on: [GDD-03-SOCIAL-STEALTH, BIBLE-NOWHERE]\n---\n# x\n"


## Every `.md` under `path`, recursively. The archive and the ADRs are included:
## a history document that names a dependency is still a route somebody follows.
func _markdown(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_markdown(path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".md"):
			out.append(path.path_join(file))
	return out


## `{id, depends_on, unreadable}` for one document's text. **PURE**, so the
## falsification tests can feed it planted text rather than planting files.
##
## `unreadable` is a `depends_on` line in any form but an inline `[..]` list —
## every one in the corpus is inline today, and a form this parser cannot read is
## a form it would otherwise pass in silence.
static func parse(text: String) -> Dictionary:
	var result := {"id": "", "depends_on": PackedStringArray(), "unreadable": false}
	var deps := PackedStringArray()
	var body := text.replace("\r", "")
	if not body.begins_with("---\n"):
		return result
	var end := body.find("\n---", 4)
	if end < 0:
		return result
	for line: String in body.substr(4, end - 4).split("\n"):
		if line.begins_with("id:"):
			result["id"] = line.trim_prefix("id:").strip_edges()
		elif line.begins_with("depends_on:"):
			var value := line.trim_prefix("depends_on:").strip_edges()
			if not (value.begins_with("[") and value.ends_with("]")):
				result["unreadable"] = true
				continue
			for item: String in value.trim_prefix("[").trim_suffix("]").split(","):
				var dep := item.strip_edges().trim_prefix('"').trim_suffix('"')
				if not dep.is_empty():
					deps.append(dep)
	# **ASSIGNED ONCE, AT THE END, AND THAT IS A FIX.** `PackedStringArray` is a
	# value type: appending to `result["depends_on"] as PackedStringArray` appended
	# to a copy, every list came back empty, and the resolve test passed over zero
	# edges. The premise test's edge count is what went red.
	result["depends_on"] = deps
	return result


## Every `path: dependency` that names no id in `known`. **An exact match**, never
## a prefix or a substring — see the header.
static func dangling(parsed: Dictionary, known: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for path: String in parsed:
		for dep: String in parsed[path]["depends_on"] as PackedStringArray:
			if not known.has(dep):
				out.append("%s: %s" % [path, dep])
	return out


func _corpus() -> Dictionary:
	var parsed := {}
	for path: String in _markdown(ROOT):
		parsed[path] = parse(FileAccess.get_file_as_string(path))
	return parsed


func _ids(parsed: Dictionary) -> Dictionary:
	var known := {}
	for path: String in parsed:
		var id: String = parsed[path]["id"]
		if not id.is_empty():
			known[id] = known.get(id, PackedStringArray()) + PackedStringArray([path])
	return known


## PREMISE. An empty walk has no dangling references and passes everything below.
func test_the_corpus_was_actually_read() -> void:
	var parsed := _corpus()
	var edges := 0
	for path: String in parsed:
		edges += (parsed[path]["depends_on"] as PackedStringArray).size()
	assert_gt(parsed.size(), 150, "the walk found almost no documents")
	assert_gt(_ids(parsed).size(), 150, "almost no document declared an id")
	assert_gt(edges, 300, "almost no depends_on edge was read, so none was checked")


func test_every_dependency_resolves_to_a_document() -> void:
	var parsed := _corpus()
	var bad := dangling(parsed, _ids(parsed))
	assert_eq(
		bad.size(),
		0,
		(
			"depends_on names a document that does not exist. A fresh session follows "
			+ "this chain to decide what to read:\n    "
			+ "\n    ".join(bad)
		)
	)


func test_every_dependency_line_is_one_this_guard_can_read() -> void:
	var parsed := _corpus()
	var bad := PackedStringArray()
	for path: String in parsed:
		if parsed[path]["unreadable"]:
			bad.append(path)
	assert_eq(
		bad.size(),
		0,
		(
			"a depends_on line is not an inline [..] list, so its entries went unchecked:\n    "
			+ "\n    ".join(bad)
		)
	)


## Two documents claiming one id make every dependency on it ambiguous: it
## resolves, and nobody can say to which.
func test_no_two_documents_share_an_id() -> void:
	var known := _ids(_corpus())
	var shared := PackedStringArray()
	for id: String in known:
		if (known[id] as PackedStringArray).size() > 1:
			shared.append("%s: %s" % [id, ", ".join(known[id])])
	assert_eq(shared.size(), 0, "two documents declare one id:\n    " + "\n    ".join(shared))


# --- falsification ----------------------------------------------------------


func test_the_check_can_actually_fail() -> void:
	var parsed := {"planted.md": parse(PLANTED)}
	var known := {"GDD-03-SOCIAL-STEALTH": true, "US-9999": true}
	assert_eq(
		dangling(parsed, known),
		PackedStringArray(["planted.md: BIBLE-NOWHERE"]),
		"a dependency on a document that does not exist was not reported"
	)


## **THE DEFECT THIS GUARD WAS WRITTEN FOR, AS A TEST.** Every one of the five was a
## prefix of a real id, and the grep that first counted them matched by substring.
func test_a_prefix_of_a_real_id_is_still_dangling() -> void:
	var text := "---\nid: US-9998\ndepends_on: [GDD-03-SOCIAL]\n---\n"
	var parsed := {"planted.md": parse(text)}
	var known := {"GDD-03-SOCIAL-STEALTH": true}
	assert_eq(dangling(parsed, known).size(), 1, "a prefix of a real id was accepted")


func test_a_multiline_list_is_reported_rather_than_passed() -> void:
	var text := "---\nid: US-9997\ndepends_on:\n  - BIBLE-NOWHERE\n---\n"
	assert_true(parse(text)["unreadable"], "a block list was read as no dependencies at all")


func test_crlf_frontmatter_is_read() -> void:
	var parsed := parse(PLANTED.replace("\n", "\r\n"))
	assert_eq(parsed["id"], "US-9999", "a CRLF file lost its id")
	assert_eq((parsed["depends_on"] as PackedStringArray).size(), 2, "a CRLF file lost its list")
