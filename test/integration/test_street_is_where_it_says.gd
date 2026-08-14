## The walkable surface is at the height the layout declares, and a market stall
## is vaultable from it. GDD-05 §4.1, US-0017–0020.
##
## **THE STALLS WERE NOT VAULTABLE, AND THE VAULT WAS FINE.** `FLOORS` gives the
## height of the walkable *surface*, and the generator built each slab straddling
## that height instead of hanging below it — so the street's top landed at 0.100
## rather than 0.000. Everything measured from the layout stayed where it was: a
## 0.9 m stall counter is 0.9 m *absolute*, which is only **0.80 m above a pawn
## standing at 0.10**. `TUN-TRAVERSE-PROBE-HEIGHT-WAIST` is 0.85, so the probe
## passed five centimetres over every stall in the district and pressing traverse
## at one did nothing at all.
##
## **Why every existing test missed it.** `test_traversal_probes_geometry.gd`
## builds its own boxes and places the pawn itself, so its floor is exact.
## `test_client_boot_walks.gd` vaults a 1.8 m block, which is in the *mantle*
## band — ten centimetres of error does not move it out of a band 1.2 m wide. The
## vault band is 0.9–1.1, and the only geometry in it is the stalls, which nothing
## had ever tried to vault.
##
## So this asserts the two claims that were false, in the order they failed: the
## surface is where the table says, and a stall is vaultable from a pawn standing
## on it.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## StallA: x 36–42, z 18–20, top at `H_VAULT`. Stand south of it, facing +Z.
const STALL_X := 39.0
const STALL_FACE_Z := 18.0

var _root: Node
var _driver: LocalPawnDriver


func before_each() -> void:
	_release_everything()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


func _run(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


## The first solid surface under `where`, or NAN.
func _surface_under(where: Vector3) -> float:
	var space := _root.get_viewport().world_3d.direct_space_state
	var from := where + Vector3.UP * 4.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0)
	query.collision_mask = CollisionLayers.WORLD
	var hit := space.intersect_ray(query)
	return NAN if hit.is_empty() else (hit["position"] as Vector3).y


# ------------------------------------------------------- where the ground is --


func test_the_street_is_at_the_height_the_layout_declares() -> void:
	# **NOT "the street is near zero".** Against `VetraioLayout.STREET_Y`, so the
	# assertion stays true if the table ever moves the street.
	var y := _surface_under(Vector3(STALL_X, 0.0, 15.0))
	assert_false(is_nan(y), "no floor under the market at all")
	assert_almost_eq(y, VetraioLayout.STREET_Y, 0.01, "the walkable surface is not where it says")


func test_every_spawn_point_stands_on_the_surface_it_names() -> void:
	# A spawn 0.1 m out is invisible; the pawn settles. What it changes is every
	# probe height for the rest of that life.
	var map := load("res://data/maps/map_vetraio.tres") as MapData
	for point: Vector3 in map.spawn_points:
		var y := _surface_under(point)
		assert_false(is_nan(y), "spawn point %v has no floor" % point)
		assert_almost_eq(y, point.y, 0.01, "spawn %v does not stand on its own surface" % point)


func test_a_stall_stands_a_vault_above_the_street() -> void:
	# The number that matters is the DIFFERENCE, not either height: a stall and a
	# street that are both 0.1 m out would still be vaultable.
	var street := _surface_under(Vector3(STALL_X, 0.0, 15.0))
	var stall := _surface_under(Vector3(STALL_X, 0.0, 19.0))
	assert_almost_eq(stall - street, VetraioLayout.H_VAULT, 0.01, "a stall is not a vault high")


func test_a_stall_is_inside_the_vault_band() -> void:
	var street := _surface_under(Vector3(STALL_X, 0.0, 15.0))
	var stall := _surface_under(Vector3(STALL_X, 0.0, 19.0))
	var above := stall - street
	assert_lte(above, Tuning.movement.traverse_vault_max_height, "a stall reads as a mantle")
	assert_gt(above, Tuning.movement.probe_height_waist, "the waist probe passes over a stall")


# --------------------------------------------------- and it can be vaulted --


func test_walking_into_a_stall_and_pressing_traverse_vaults_it() -> void:
	# **THE END-TO-END CLAIM, THROUGH THE REAL BINDINGS.** The probes can be
	# right, the resolver can be right, and the player can still press Space at a
	# market counter and get nothing — which is exactly what happened.
	_driver.ctx.position = Vector3(STALL_X, VetraioLayout.STREET_Y, STALL_FACE_Z - 2.5)
	_driver.ctx.yaw = 0.0
	(_driver.get_node(_driver.pawn_path) as Node3D).global_position = _driver.ctx.position
	await _run(4)

	Input.action_press(&"input_move_forward")
	await _run(70)
	Input.action_press(&"input_traverse")
	await _run(4)

	var reached := _driver.ctx.state_id
	await _run(60)
	var crossed := _driver.ctx.position.z - STALL_FACE_Z
	assert_eq(reached, PawnStateId.VAULT, "pressing traverse at a stall did nothing")
	assert_gt(crossed, 0.0, "the vault did not carry the pawn onto or over the counter")
