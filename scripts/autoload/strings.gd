## String-table lookup. No user-facing literal exists anywhere else (ASM-0023).
##
## LOCALISATION IS OUT OF SCOPE; THE TABLE IS NOT. Retrofitting a string table
## across a finished UI is a multi-day refactor with a long tail of missed
## strings — the ones nobody finds until a player screenshots them. Doing it from
## commit one costs approximately nothing and turns the deferred work into a data
## task: add a column to the CSV.
##
## It also gives the IP guardrails ONE place to review every word a player can
## read. Vocabulary scattered across forty scenes cannot be reviewed at all.
extends Node

const TABLE := "res://data/strings/en.csv"

## Reserved key namespaces. A key outside these is a key nobody will find later.
## `passive` was added in US-0011: PassiveData needs display keys and the
## original list in the story omitted it.
const NAMESPACES: Array[String] = [
	"ui",
	"bonus",
	"ability",
	"passive",
	"persona",
	"caption",
	"credits",
	"menu",
]

var _table: Dictionary = {}


func _ready() -> void:
	_load()


## The string for `key`.
##
## NOT NAMED `get`. Object.get(property) already exists, and shadowing it on an
## autoload would break every engine call that reaches for a property by name.
## US-0011's acceptance criterion says `Strings.get(key)`; this is that function
## under a name the engine has not already taken.
##
## A miss logs and RETURNS THE KEY, so a missing string shows up in-game as
## `ui.thing.missing` rather than as empty space. Blank text is invisible in a
## screenshot; a key is not.
func get_text(key: StringName) -> String:
	if _table.has(key):
		return String(_table[key])
	Log.error("missing string key: %s" % key, &"strings")
	return String(key)


func has(key: StringName) -> bool:
	return _table.has(key)


func count() -> int:
	return _table.size()


func keys() -> Array:
	return _table.keys()


func _load() -> void:
	_table.clear()
	var file := FileAccess.open(TABLE, FileAccess.READ)
	if file == null:
		Log.error("string table missing: %s" % TABLE, &"strings")
		return
	var header := file.get_csv_line()
	if header.size() < 2 or header[0] != "keys":
		Log.error("string table header must start with 'keys'", &"strings")
		return
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		_table[StringName(row[0].strip_edges())] = row[1]
	Log.info("Strings: %d keys" % _table.size(), &"strings")
