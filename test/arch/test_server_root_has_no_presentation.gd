## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## `server_root.tscn` contains no presentation, and the export presets exclude
## the layers that would let it.
##
## Why review misses this: a Camera3D or a CanvasLayer in the server scene costs
## nothing on a developer machine, where the whole project is present. It breaks
## only in the dedicated server EXPORT, where `scripts/presentation/` and
## `scenes/ui/` are gone — so the failure arrives at deploy time, in a build
## nobody runs locally, as a scene that will not instantiate.
##
## The server preset's exclusion list is the architecture's proof (TDD-01 §1.2).
extends GutTest

const SERVER_ROOT := "res://scenes/server_root.tscn"
const PRESETS := "res://export_presets.cfg"

## Node types that only make sense with a screen attached.
const VISUAL_TYPES: Array[String] = [
	"Camera3D",
	"CanvasLayer",
	"Control",
	"Label",
	"Sprite2D",
	"MeshInstance3D",
	"OmniLight3D",
	"DirectionalLight3D",
	"WorldEnvironment",
	"AudioStreamPlayer",
	"AnimationPlayer",
]


func test_the_server_scene_declares_no_visual_nodes() -> void:
	var text := _code_only(SERVER_ROOT)
	assert_ne(text, "", "server_root.tscn is missing")
	var offenders: PackedStringArray = []
	for type_name: String in VISUAL_TYPES:
		if text.contains('type="%s"' % type_name):
			offenders.append(type_name)
	assert_eq(
		offenders.size(),
		0,
		(
			"server_root.tscn contains presentation nodes: %s\n" % String(", ").join(offenders)
			+ "The dedicated server export excludes presentation entirely; this scene\n"
			+ "would fail to instantiate in the build nobody runs locally."
		)
	)


func test_the_server_scene_references_no_presentation_script() -> void:
	# Comments stripped first. The scene's own header explains WHY those layers are
	# absent, and a guard that reads its own documentation reports itself.
	var text := _code_only(SERVER_ROOT)
	var offenders: PackedStringArray = []
	for path: String in ["scripts/presentation", "scripts/mirrors", "scenes/ui"]:
		if text.contains(path):
			offenders.append(path)
	assert_eq(offenders.size(), 0, "server_root.tscn references " + String(", ").join(offenders))


func test_the_server_preset_excludes_every_client_layer() -> void:
	var text := SourceScanner.read(PRESETS)
	assert_ne(text, "", "export_presets.cfg is missing")
	var server_section := text.split("[preset.1]")[0]
	var missing: PackedStringArray = []
	for path: String in [
		"scripts/presentation/", "scripts/mirrors/", "scenes/ui/", "addons/gut/", "scripts/debug/"
	]:
		if not server_section.contains(path):
			missing.append(path)
	assert_eq(
		missing.size(),
		0,
		(
			"The server preset does not exclude: %s\n" % String(", ").join(missing)
			+ "That list is the architecture's proof, not a size optimisation."
		)
	)


func test_no_preset_ships_the_test_framework() -> void:
	# A test framework inside a shipped build is a size cost and an attack surface.
	var text := SourceScanner.read(PRESETS)
	var sections := text.split("exclude_filter=")
	var offenders: PackedStringArray = []
	for i: int in range(1, sections.size()):
		var value: String = sections[i].split("\n")[0]
		if not value.contains("addons/gut/"):
			offenders.append("preset %d does not exclude addons/gut/" % (i - 1))
	assert_eq(offenders.size(), 0, "\n".join(offenders))


func test_the_release_client_presets_strip_the_debug_console() -> void:
	# DebugConsole is an autoload, so the export filter is the ONLY thing keeping
	# it out of players' hands.
	var text := SourceScanner.read(PRESETS)
	var release := text.split("[preset.3]")[0]  # presets 0-2 are the release builds
	var sections := release.split("exclude_filter=")
	var offenders: PackedStringArray = []
	for i: int in range(1, sections.size()):
		var value: String = sections[i].split("\n")[0]
		if not value.contains("scripts/debug/"):
			offenders.append("release preset %d ships scripts/debug/" % (i - 1))
	assert_eq(offenders.size(), 0, "\n".join(offenders))


## A .tscn with its `;` comment lines removed.
static func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in SourceScanner.read(path).split("\n"):
		if not line.strip_edges().begins_with(";"):
			out.append(line)
	return "\n".join(out)
