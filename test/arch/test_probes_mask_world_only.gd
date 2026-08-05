## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **TRAVERSAL PROBES MASK `WORLD` AND NOTHING ELSE.**
##
## This is a determinism requirement, not an optimisation. Static geometry is
## identical on every peer by construction. NPC and player positions are
## interpolated on clients and authoritative on the server, so a probe that could
## hit a moving body resolves differently on the two machines — the client
## predicts a vault the server never performed, the correction snaps the pawn
## backwards through the wall it just climbed, and the bug reads as "the netcode
## is bad" rather than as one wrong constant.
##
## Why review misses it: `collision_mask = 3` looks like a considered choice.
## Nothing errors, nothing fails, and the divergence only appears under a crowd
## — which is to say, only in the situation the whole game is about.
##
## US-0017's test notes call this the important one.
extends GutTest

const PROBE_SOURCES: Array[String] = ["res://scripts/pawn/traversal"]


func test_the_traversal_mask_is_world_alone() -> void:
	assert_eq(
		CollisionLayers.TRAVERSAL_MASK,
		CollisionLayers.WORLD,
		"the traversal mask is no longer WORLD alone"
	)


func test_the_mask_excludes_every_moving_layer() -> void:
	# Named individually, so a failure says WHICH layer leaked in rather than
	# printing two integers and leaving the reader to decode them.
	var leaked: PackedStringArray = []
	for name: StringName in [&"PAWN", &"NPC", &"TRIGGER"]:
		if (CollisionLayers.TRAVERSAL_MASK & CollisionLayers.BY_NAME[name]) != 0:
			leaked.append(String(name))
	assert_eq(
		leaked.size(),
		0,
		(
			"Traversal probes can see a moving layer: "
			+ ", ".join(leaked)
			+ "\nClient and server would resolve different traversals (TDD-03 §3.3)."
		)
	)


func test_no_probe_writes_a_raw_collision_mask() -> void:
	# A literal is how the mask widens without anyone deciding to. Every cast goes
	# through `CollisionLayers.TRAVERSAL_MASK`, so widening it is one visible edit.
	var violations: PackedStringArray = []
	for root: String in PROBE_SOURCES:
		for path: String in SourceScanner.gd_files(root):
			for pair: Array in SourceScanner.code_lines(path):
				var line := String(pair[1])
				if not line.contains("collision_mask"):
					continue
				if line.contains("CollisionLayers."):
					continue
				violations.append("%s:%d %s" % [path, pair[0], line.strip_edges()])
	assert_eq(
		violations.size(),
		0,
		"A probe sets a collision mask without naming the layer:\n" + "\n".join(violations)
	)


func test_the_probe_sources_exist_to_be_scanned() -> void:
	# Guards the guard. An empty scan passes the check above in silence.
	var count := 0
	for root: String in PROBE_SOURCES:
		count += SourceScanner.gd_files(root).size()
	assert_gt(count, 1, "the traversal source scan matched almost nothing")


func test_the_layer_names_still_match_project_godot() -> void:
	# `CollisionLayers` is a mirror of `[layer_names]`, and a mirror drifts. If
	# someone renamed layer 3 to WORLD, every assertion above would keep passing
	# while meaning the opposite.
	var text := SourceScanner.read("res://project.godot")
	var wrong: PackedStringArray = []
	var index := 1
	for name: StringName in CollisionLayers.BY_NAME:
		var expected := '3d_physics/layer_%d="%s"' % [index, name]
		if not text.contains(expected):
			wrong.append(expected)
		if CollisionLayers.BY_NAME[name] != 1 << (index - 1):
			wrong.append("%s is not bit %d" % [name, index - 1])
		index += 1
	assert_eq(
		wrong.size(),
		0,
		"CollisionLayers has drifted from project.godot [layer_names]:\n" + "\n".join(wrong)
	)


func test_both_pawn_scenes_carry_the_same_probes() -> void:
	# TDD-06 §1.1 rule 1: `PawnServer` and `PawnLocal` share `TraversalProbes`
	# verbatim. Reconciliation replays inputs through the identical code path, so
	# a probe script on one and not the other is a prediction divergence with no
	# error message.
	var missing: PackedStringArray = []
	for scene: String in [
		"res://scenes/pawn/pawn_local.tscn", "res://scenes/pawn/pawn_server.tscn"
	]:
		var text := SourceScanner.read(scene)
		if not text.contains("scripts/pawn/traversal/traversal_probes.gd"):
			missing.append(scene)
	assert_eq(missing.size(), 0, "pawn scene without TraversalProbes: " + ", ".join(missing))
