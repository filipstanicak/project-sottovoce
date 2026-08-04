## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Max 40 lines per function, 400 per file (CODING_STANDARDS section 6).
##
## These are design signals, not style preferences. A function reaching 40
## lines is usually doing two things; a file reaching 400 usually wants
## splitting. gdlint enforces the file limit; it cannot express the function
## limit, which is why this exists.
extends GutTest

const MAX_FUNCTION_LINES := 40
const MAX_FILE_LINES := 400
const ROOTS: Array[String] = ["res://scripts", "res://tools"]


func test_no_function_exceeds_the_limit() -> void:
	var violations: PackedStringArray = []
	for root: String in ROOTS:
		for path: String in SourceScanner.gd_files(root):
			violations.append_array(_long_functions(path))
	assert_eq(
		violations.size(),
		0,
		"Function too long — it is probably doing two things.\n" + "\n".join(violations)
	)


func test_no_file_exceeds_the_limit() -> void:
	var violations: PackedStringArray = []
	for root: String in ROOTS:
		for path: String in SourceScanner.gd_files(root):
			var count := SourceScanner.read(path).split("\n").size()
			if count > MAX_FILE_LINES:
				violations.append("%s is %d lines (max %d)" % [path, count, MAX_FILE_LINES])
	assert_eq(violations.size(), 0, "\n".join(violations))


func _long_functions(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var lines := SourceScanner.read(path).split("\n")
	var start := -1
	var fname := ""
	for i: int in lines.size():
		var stripped := lines[i].strip_edges()
		var is_decl := stripped.begins_with("func ") or stripped.begins_with("static func ")
		if is_decl:
			if start >= 0 and (i - start) > MAX_FUNCTION_LINES:
				out.append("%s:%d %s is %d lines" % [path, start + 1, fname, i - start])
			start = i
			fname = stripped.split("(")[0].replace("static func ", "").replace("func ", "")
	if start >= 0 and (lines.size() - start) > MAX_FUNCTION_LINES:
		out.append("%s:%d %s is %d lines" % [path, start + 1, fname, lines.size() - start])
	return out
