## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **`pawn_local.tscn` AND `pawn_server.tscn` ARE THE SAME PAWN.** Same collision
## shape, same offset, same layers, same state machine, same probes. TDD-06 §1.1
## rule 1 calls this the chapter's highest-value test, and §8 names it.
##
## Reconciliation replays buffered inputs through the identical code path the
## server used. A divergence in shape, in layer mask, or in where the capsule
## sits relative to the body origin is a divergence in *prediction* — the client
## and the server disagree about where the pawn is, forever, at a millimetre a
## tick.
##
## Why review misses it: the failure is a tweak to the local pawn for a camera or
## an animation reason, made in a scene file, by someone who has never opened the
## server one. It is the single most likely way this codebase breaks prediction,
## and it produces no error at all.
##
## US-0017 moved the capsule up by half its height in both scenes — the body
## origin is the pawn's FEET, because `MapData.spawn_points` and
## `TUN-TRAVERSE-PROBE-HEIGHT-*` are both measured from the ground. Doing that to
## one scene and not the other would have put the server's probes 0.9 m below the
## client's.
extends GutTest

const LOCAL := "res://scenes/pawn/pawn_local.tscn"
const SERVER := "res://scenes/pawn/pawn_server.tscn"

## Lines that must appear identically in both scenes. Compared as text rather
## than by instantiating, because a scene that fails to load is also a failure
## and this has to say which line diverged.
const MUST_MATCH: Array[String] = [
	"radius = 0.35",
	"height = 1.8",
	"collision_layer = 2",
	"collision_mask = 1",
	"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)",
	"res://scripts/pawn/pawn_state_machine.gd",
	"res://scripts/pawn/traversal/traversal_probes.gd",
]


func _text(path: String) -> String:
	var out := SourceScanner.read(path)
	assert_ne(out, "", "%s is missing or unreadable" % path)
	return out


func test_both_scenes_declare_every_shared_property() -> void:
	var missing: PackedStringArray = []
	for path: String in [LOCAL, SERVER]:
		var text := _text(path)
		for line: String in MUST_MATCH:
			if not text.contains(line):
				missing.append("%s lacks: %s" % [path.get_file(), line])
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		(
			"The two pawn scenes have diverged. Reconciliation replays inputs through\n"
			+ "the same code path, so this is a prediction bug with no error message.\n"
			+ "\n".join(missing)
		)
	)


func test_the_capsule_sits_on_the_body_origin() -> void:
	# HALF THE CAPSULE HEIGHT, exactly. Centred on the origin, the pawn spawns
	# buried to the waist on any spawn point and every probe looks from 0.9 m too
	# low — which is how US-0017 found the pawn had been falling through the map.
	var text := _text(LOCAL)
	var height := _float_after(text, "height = ")
	var offset := _capsule_y_offset(text)
	assert_gt(height, 0.0, "the pawn capsule has no height")
	assert_almost_eq(
		offset,
		height * 0.5,
		0.001,
		"the capsule is not raised by half its height — the body origin is not the feet"
	)


func test_the_server_pawn_carries_no_presentation() -> void:
	# The server export excludes presentation entirely (TDD-01 §1.2). A camera
	# mount or a footstep emitter on the server pawn is a build failure waiting
	# for the export job.
	var text := _text(SERVER)
	var strays: PackedStringArray = []
	for node: String in ["CameraMount", "PersonaVisuals", "FootstepEmitter", "MeshInstance3D"]:
		if text.contains(node):
			strays.append(node)
	assert_eq(strays.size(), 0, "pawn_server.tscn carries presentation: " + ", ".join(strays))


func test_the_local_pawn_does_carry_presentation() -> void:
	# Guards the guard: if the node names above were renamed, the check would pass
	# against a server scene that still had all of them under new names.
	var text := _text(LOCAL)
	assert_true(text.contains("CameraMount"), "pawn_local.tscn lost its camera mount")
	assert_true(text.contains("PersonaVisuals"), "pawn_local.tscn lost its visuals")


func test_the_pawn_is_on_the_pawn_layer_and_probes_only_world() -> void:
	# `collision_layer = 2` is PAWN, `collision_mask = 1` is WORLD. Written as
	# integers by the scene format, so they are checked against the named
	# constants rather than trusted.
	assert_eq(CollisionLayers.PAWN, 2, "the PAWN layer moved; both pawn scenes need updating")
	assert_eq(CollisionLayers.WORLD, 1, "the WORLD layer moved; both pawn scenes need updating")


func _float_after(text: String, marker: String) -> float:
	var at := text.find(marker)
	if at < 0:
		return 0.0
	var tail := text.substr(at + marker.length(), 16)
	return tail.split("\n")[0].strip_edges().to_float()


## The `y` translation of the `CollisionShape3D` transform, which in Godot's
## scene format is the eleventh number of the `Transform3D(...)` call.
func _capsule_y_offset(text: String) -> float:
	var re := RegEx.create_from_string("Transform3D\\(([^)]*)\\)")
	var m := re.search(text)
	if m == null:
		return 0.0
	var parts := m.get_string(1).split(",")
	return 0.0 if parts.size() < 12 else parts[10].strip_edges().to_float()
