## Harvests every ID out of the docs corpus, for the guards that keep `Ids` and
## the documentation from drifting apart.
##
## Scans Markdown as TEXT. The corpus is the source of truth for what an ID *is*;
## `scripts/core/ids.gd` is a mirror of the subset code refers to at runtime.
class_name IdScanner
extends RefCounted

## Namespace -> grammar, from docs/30_bible/NAMING_AND_IDS.md §1. Kept in sync by
## `test_id_grammar.gd`, which fails if this table and that section disagree.
const GRAMMAR := {
	"SYS": "^SYS-[A-Z][A-Z0-9]*(-[A-Z0-9]+)*$",
	"INPUT": "^INPUT-[A-Z]+(-[A-Z0-9]+)*$",
	"SCORE": "^SCORE-[A-Z]+$",
	"ABIL": "^ABIL-[A-Z]+$",
	"PASV": "^PASV-[A-Z]+$",
	"PERSONA": "^PERSONA-[A-Z]+$",
	"ARCH": "^ARCH-[A-Z]+$",
	"MAP": "^MAP-[A-Z]+$",
	"LOC": "^LOC-[A-Z]+$",
	"NET": "^NET-(C2S|S2C)-[A-Z]+(-[A-Z]+)*$",
	"EVT": "^EVT-[A-Z]+(-[A-Z]+)*$",
	"SFX": "^SFX-[A-Z]+(-[A-Z]+)*$",
	"MUS": "^MUS-[A-Z]+(-[A-Z]+)*$",
	"ANIM": "^ANIM-[A-Z]+(-[A-Z]+)*$",
	"MAT": "^MAT-[A-Z]+(-[A-Z]+)*$",
	"PROP": "^PROP-[A-Z]+$",
	"TEL": "^TEL-[A-Z]+(-[A-Z]+)*$",
	"RISK": "^RISK-[A-Z]+(-[A-Z]+)*$",
}

## The namespaces `Ids` mirrors, because code names these at runtime.
##
## Deliberately NOT mirrored: SYS- and RISK- are documentation-only; US-, ADR-
## and ASM- are register entries; TUN- has its own mechanism (US-0007); LOC-,
## MAT-, PROP- and TEL- are runtime-bound but arrive with the systems that
## consume them, so mirroring them now would be a list nothing reads.
const MIRRORED: Array[String] = [
	"INPUT", "SCORE", "ABIL", "PASV", "PERSONA", "ARCH", "MAP", "EVT", "NET", "SFX", "MUS", "ANIM"
]

## Declared in the corpus with a namespace prefix, but NOT a member of that
## namespace's runtime set. These are excluded from the mirror deliberately.
##
## SCORE-EVENT names the immutable log record itself — the thing every SCORE-*
## kind is an instance OF. Putting it in `Ids` beside SCORE-BLENDED would invite
## appending it to the log as a kind, and an ID is immutable once merged, so the
## hazard would be permanent. Resolved with the project owner, US-0006.
const NOT_A_MEMBER := {
	"SCORE-EVENT": "the ScoreEvent record type, not a score kind",
}

const _DOCS_ROOT := "res://docs"


## Every ID in the corpus, as namespace -> sorted Array[String].
static func ids_in_corpus() -> Dictionary:
	var out: Dictionary = {}
	for ns: String in GRAMMAR:
		out[ns] = {}
	for path: String in _md_files(_DOCS_ROOT):
		_harvest(FileAccess.get_file_as_string(path), out)
	var sorted: Dictionary = {}
	for ns: String in out:
		var keys: Array = out[ns].keys()
		keys.sort()
		sorted[ns] = keys
	return sorted


static func _harvest(text: String, out: Dictionary) -> void:
	for ns: String in GRAMMAR:
		# Not preceded by an ID character, so TUN-PASV-STILLNESS-MULT does not
		# yield a bogus PASV-STILLNESS-MULT.
		var re := RegEx.create_from_string("(?<![A-Z0-9\\-])" + ns + "-[A-Z0-9\\-]+")
		for m: RegExMatch in re.search_all(text):
			# `NET-S2C-*` in a diagram globs a namespace; it is not an ID.
			if text.substr(m.get_end(), 1) == "*":
				continue
			out[ns][m.get_string().rstrip("-")] = true


static func _md_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	_walk(root, out)
	return out


static func _walk(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := path.path_join(entry)
			if dir.current_is_dir():
				_walk(full, out)
			elif entry.ends_with(".md"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


## The `Ids` constant map: constant name -> value.
static func id_constants() -> Dictionary:
	var script := load("res://scripts/core/ids.gd") as GDScript
	return script.get_script_constant_map()
