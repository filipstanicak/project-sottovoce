## **THE SEVEN CASES, FROM REAL GEOMETRY.** GDD-02 §7.2, TDD-06 §4.2.
##
## `test_traversal_resolution.gd` asserts the priority order against hand-filled
## `ProbeResult`s, which is the only way to test an ordering. This file closes
## the other half: that the probes, cast at the heights the level-design contract
## actually builds, produce numbers the resolver reads the intended way.
##
## Both are needed. A resolver with a perfect ordering over numbers no probe
## produces resolves nothing, and every unit test in the project would still be
## green.
extends GutTest

const FACING := TraversalWorld.FACING

var _world: TraversalWorld
var _probes: TraversalProbes


func before_each() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	_world = TraversalWorld.new(host)
	_probes = TraversalProbes.new()
	_world.root.add_child(_probes)


## Refresh the probes against whatever this test built, and hand back the context
## the resolver will read.
func _resolved(grounded: bool = true) -> PawnContext:
	var ctx := TraversalWorld.context(Vector3.ZERO, FACING, grounded)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_probes.refresh(ctx)
	return ctx


func test_real_geometry_resolves_to_a_vault() -> void:
	_world.obstacle(0.9, 0.7)
	var ctx := await _resolved()
	assert_eq(TraversalResolver.classify(ctx), TraversalResolver.Case.VAULT)


func test_real_geometry_resolves_to_a_mantle() -> void:
	_world.obstacle(1.8, 0.7)
	var ctx := await _resolved()
	assert_eq(TraversalResolver.classify(ctx), TraversalResolver.Case.MANTLE)


func test_real_geometry_resolves_to_a_climb() -> void:
	_world.obstacle(4.0, 0.7)
	var ctx := await _resolved()
	assert_eq(TraversalResolver.classify(ctx), TraversalResolver.Case.CLIMB)


func test_real_geometry_resolves_to_a_gap_jump() -> void:
	_world.open_gap(0.5, 2.5)
	var ctx := await _resolved()
	assert_eq(TraversalResolver.classify(ctx), TraversalResolver.Case.GAP_JUMP)


func test_real_geometry_resolves_to_a_drop() -> void:
	_world.open_gap(0.5, 1000.0)
	var ctx := await _resolved()
	assert_eq(TraversalResolver.classify(ctx), TraversalResolver.Case.DROP)


func test_an_empty_street_resolves_to_silence() -> void:
	# **CASE 7.** The commonest case in the whole game: a player presses traverse
	# in the middle of a plaza. Nothing happens, and nothing must LOOK like it
	# tried to.
	var ctx := await _resolved()
	assert_eq(TraversalResolver.classify(ctx), TraversalResolver.Case.NONE)
