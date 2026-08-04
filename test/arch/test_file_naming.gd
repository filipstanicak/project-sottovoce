## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## A file's name is the snake_case of its class_name. Without this, finding the
## file that defines a class becomes a search rather than a path computation —
## which matters most to an agent with no memory of the codebase.
extends GutTest

const ROOTS: Array[String] = ["res://scripts", "res://tools"]


func test_filename_matches_class_name() -> void:
	var violations: PackedStringArray = []
	for root: String in ROOTS:
		for path: String in SourceScanner.gd_files(root):
			var declared := _class_name_of(path)
			if declared == "":
				continue
			var expected := _to_snake(declared)
			var actual := path.get_file().get_basename()
			if actual != expected:
				violations.append(
					"%s declares class_name %s (expected file %s.gd)" % [path, declared, expected]
				)
	assert_eq(violations.size(), 0, "\n".join(violations))


func _class_name_of(path: String) -> String:
	for pair: Array in SourceScanner.code_lines(path):
		var line := String(pair[1]).strip_edges()
		if line.begins_with("class_name "):
			return line.substr(11).strip_edges().split(" ")[0]
	return ""


func _to_snake(pascal: String) -> String:
	var out := ""
	for i: int in pascal.length():
		var c := pascal[i]
		if c == c.to_upper() and c != c.to_lower() and i > 0:
			out += "_"
		out += c.to_lower()
	return out
