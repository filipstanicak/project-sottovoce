## **THE BATCH BUILDS WHAT IT WAS ASKED FOR, FACING OUT.** ADR-0026.
##
## Every part of the district's dressing goes through `MeshBatch`, and it is drawn
## with back faces culled: a face wound the wrong way is a hole in a building.
extends GutTest

const KEY := WorldMaterials.STONE

var _batch: MeshBatch


func before_each() -> void:
	_batch = MeshBatch.new()


## Every face's normal points away from `centre`.
func _faces_out(centre: Vector3) -> bool:
	var vertices := _batch.vertices_of(KEY)
	var normals := _batch.normals_of(KEY)
	for i: int in vertices.size():
		if normals[i].dot(vertices[i] - centre) <= 0.0:
			return false
	return true


func test_a_box_is_twelve_triangles_facing_out() -> void:
	_batch.box(KEY, Vector3(3, 2, 1), Vector3(2, 4, 6), WorldPalette.PLAIN)
	assert_eq(_batch.triangle_count(), 12)
	assert_true(_faces_out(Vector3(3, 2, 1)), "a face of the box looks inward")


func test_a_turned_box_still_faces_out() -> void:
	var turned := Basis(Vector3.UP, 0.7)
	_batch.box(KEY, Vector3(3, 2, 1), Vector3(2, 4, 6), WorldPalette.PLAIN, turned)
	assert_true(_faces_out(Vector3(3, 2, 1)))


func test_a_box_is_as_big_as_it_was_asked_to_be() -> void:
	_batch.box(KEY, Vector3(3, 2, 1), Vector3(2, 4, 6), WorldPalette.PLAIN)
	var low := Vector3.INF
	var high := -Vector3.INF
	for vertex: Vector3 in _batch.vertices_of(KEY):
		low = low.min(vertex)
		high = high.max(vertex)
	assert_almost_eq(low, Vector3(2, 0, -2), Vector3.ONE * 0.001)
	assert_almost_eq(high, Vector3(4, 4, 4), Vector3.ONE * 0.001)


func test_a_column_has_a_side_and_a_cap_per_spoke() -> void:
	_batch.column(KEY, Vector3.ZERO, Vector2(0.5, 2.0), 8, WorldPalette.PLAIN)
	assert_eq(_batch.triangle_count(), 8 * 3)
	assert_true(_faces_out(Vector3(0, 0.9, 0)), "a face of the column looks inward")


func test_a_cone_has_no_cap() -> void:
	_batch.column(KEY, Vector3.ZERO, Vector2(0.5, 2.0), 8, WorldPalette.PLAIN, 0.0)
	assert_eq(_batch.triangle_count(), 8 * 2)


func test_every_slope_of_a_roof_sheds_outward_and_up() -> void:
	for eaves: Vector2 in [Vector2(10, 4), Vector2(4, 10), Vector2(6, 6)]:
		_batch = MeshBatch.new()
		_batch.hip_roof(KEY, Vector3(5, 8, 5), eaves, 2.0, WorldPalette.PLAIN)
		for normal: Vector3 in _batch.normals_of(KEY):
			assert_gt(normal.y, 0.0, "a slope of a %s roof faces down" % eaves)
		assert_true(_faces_out(Vector3(5, 8, 5)), "a slope of a %s roof looks inward" % eaves)


func test_a_colour_is_stored_as_the_shader_reads_it() -> void:
	# A vertex colour is not converted on its way to the shader, a material's is.
	var palette := WorldPalette.new()
	_batch.box(KEY, Vector3.ZERO, Vector3.ONE, palette.timber)
	var mesh_host := Node3D.new()
	add_child_autofree(mesh_host)
	var instance := _batch.commit(mesh_host, WorldMaterials.new(palette), "Parts")
	var colours: PackedColorArray = instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_almost_eq(colours[0].r, palette.timber.srgb_to_linear().r, 0.01)


func test_each_key_is_one_surface_with_its_material() -> void:
	var palette := WorldPalette.new()
	var materials := WorldMaterials.new(palette)
	_batch.box(WorldMaterials.STONE, Vector3.ZERO, Vector3.ONE, WorldPalette.PLAIN)
	_batch.box(WorldMaterials.TIMBER, Vector3.ZERO, Vector3.ONE, WorldPalette.PLAIN)
	_batch.box(WorldMaterials.STONE, Vector3.ONE, Vector3.ONE, WorldPalette.PLAIN)
	var host := Node3D.new()
	add_child_autofree(host)
	var instance := _batch.commit(host, materials, "Parts")
	assert_eq(instance.mesh.get_surface_count(), 2)
	assert_eq(instance.mesh.surface_get_material(0), materials.of(WorldMaterials.STONE))
	assert_eq(instance.mesh.surface_get_material(1), materials.of(WorldMaterials.TIMBER))


func test_nothing_batched_commits_nothing() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	assert_null(_batch.commit(host, WorldMaterials.new(WorldPalette.new()), "Parts"))
	assert_eq(host.get_child_count(), 0)
