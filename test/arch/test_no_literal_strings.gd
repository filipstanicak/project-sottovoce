## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## No user-facing literal outside `data/strings/`.
##
## Why review misses this: `label.text = "Exposed"` is correct, readable and
## works. It is also invisible to the string table, so the day localisation or a
## vocabulary review happens, that word is not in the list of words the game
## says. The IP guardrails depend on ONE place holding every player-visible term;
## a literal in a scene defeats that quietly and permanently.
##
## Scanned properties are the ones that render text to a human.
extends GutTest

const TEXT_PROPERTIES: Array[String] = [
	".text = ",
	".tooltip_text = ",
	".placeholder_text = ",
	".title = ",
	".hint_tooltip = ",
	".dialog_text = ",
]

const ROOTS: Array[String] = [
	"res://scripts/presentation",
	"res://scripts/mirrors",
	"res://scripts/core",
	"res://scripts/systems",
	"res://scripts/net",
	"res://scripts/pawn",
	"res://scripts/server",
	"res://scripts/autoload",
]


func test_no_script_assigns_a_literal_to_a_text_property() -> void:
	# SourceScanner blanks string literals before matching, so an assignment from
	# a literal leaves `.text =` followed by nothing but whitespace — while an
	# assignment from Strings.get_text(...) leaves the call intact. That is the
	# signal: emptiness after the equals means the value was a literal.
	var violations: PackedStringArray = []
	for root: String in ROOTS:
		for path: String in SourceScanner.gd_files(root):
			for pair: Array in SourceScanner.code_lines(path):
				var code: String = String(pair[1])
				for prop: String in TEXT_PROPERTIES:
					var at := code.find(prop)
					if at == -1:
						continue
					var rhs := code.substr(at + prop.length()).strip_edges()
					if rhs == "":
						violations.append(
							"%s:%d assigns a literal to %s" % [path, pair[0], prop.strip_edges()]
						)
	violations.sort()
	assert_eq(
		violations.size(),
		0,
		(
			"A user-facing string literal was assigned in code.\n"
			+ 'Put it in data/strings/en.csv and read it with Strings.get_text(&"key").\n'
			+ "\n".join(violations)
		)
	)


func test_no_scene_embeds_a_text_property() -> void:
	# .tscn files are the other half. A Label with its text typed into the editor
	# never appears in any script, so a script-only scan would report success.
	var violations: PackedStringArray = []
	for path: String in _scenes("res://scenes"):
		var lineno := 0
		for raw: String in SourceScanner.read(path).split("\n"):
			lineno += 1
			var line := raw.strip_edges()
			for prop: String in ['text = "', 'tooltip_text = "', 'placeholder_text = "']:
				if line.begins_with(prop) and not line.ends_with('= ""'):
					violations.append("%s:%d %s" % [path, lineno, line])
	violations.sort()
	assert_eq(
		violations.size(),
		0,
		(
			"A scene embeds user-facing text. It belongs in data/strings/en.csv.\n"
			+ "\n".join(violations)
		)
	)


func test_the_string_table_exists_and_is_populated() -> void:
	# Guards the guard: if the table were empty, every widget would be reading
	# keys back as text and the checks above would still pass.
	assert_true(Strings.count() > 20, "the string table has almost no keys")


func test_every_key_is_in_a_reserved_namespace() -> void:
	var stray: PackedStringArray = []
	for key: StringName in Strings.keys():
		var head := String(key).split(".")[0]
		if not Strings.NAMESPACES.has(head):
			stray.append(String(key))
	stray.sort()
	assert_eq(
		stray.size(),
		0,
		(
			"A string key is outside the reserved namespaces %s.\n" % str(Strings.NAMESPACES)
			+ "\n".join(stray)
		)
	)


static func _scenes(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := root.path_join(entry)
			if dir.current_is_dir():
				out.append_array(_scenes(full))
			elif entry.ends_with(".tscn"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
