## **MANY SMALL PARTS, ONE MESH PER MATERIAL.** ADR-0026. CLIENT ONLY.
##
## The district's dressing is thousands of parts — window surrounds, shutters,
## cornices, awning posts. A node each would be thousands of draw calls; collected
## here by material they are about ten. Each part carries its colour per vertex,
## which the surface shader multiplies in.
##
## **FLAT-SHADED AND UNINDEXED.** Every part is a box, a slab or a prism, whose
## faces want their own normals; sharing vertices would round every corner.
##
## Callers give faces counter-clockwise as seen from outside; the engine's
## clockwise winding is produced here, once.
class_name MeshBatch
extends RefCounted

## The corners of a unit cube, and its six faces counter-clockwise from outside.
const CORNERS: Array[Vector3] = [
	Vector3(-0.5, -0.5, -0.5),
	Vector3(0.5, -0.5, -0.5),
	Vector3(0.5, 0.5, -0.5),
	Vector3(-0.5, 0.5, -0.5),
	Vector3(-0.5, -0.5, 0.5),
	Vector3(0.5, -0.5, 0.5),
	Vector3(0.5, 0.5, 0.5),
	Vector3(-0.5, 0.5, 0.5),
]
const FACES: Array[Array] = [
	[4, 5, 6, 7],
	[1, 0, 3, 2],
	[5, 1, 2, 6],
	[0, 4, 7, 3],
	[7, 6, 2, 3],
	[0, 1, 5, 4],
]


## What one material's parts add up to. A class rather than three dictionaries of
## packed arrays, because a packed array read out of a dictionary is copied on the
## first append — every triangle would copy every triangle before it.
class Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()


var _surfaces: Dictionary = {}


## One triangle, counter-clockwise from outside.
func tri(key: StringName, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var surface := _surfaces.get(key) as Surface
	if surface == null:
		surface = Surface.new()
		_surfaces[key] = surface
	var normal := (b - a).cross(c - a).normalized()
	# A vertex colour reaches the shader as it is stored, where a material's
	# colour is converted for it: the palette is authored in sRGB, so convert here
	# or every batched part is drawn paler than the wall it hangs on.
	var linear := colour.srgb_to_linear()
	surface.vertices.append_array([a, c, b])
	surface.normals.append_array([normal, normal, normal])
	surface.colours.append_array([linear, linear, linear])


## One flat four-sided face, counter-clockwise from outside.
func quad(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	tri(key, a, b, c, colour)
	tri(key, a, c, d, colour)


## A box of `size` centred on `centre`, turned by `basis`.
func box(
	key: StringName, centre: Vector3, size: Vector3, colour: Color, basis := Basis.IDENTITY
) -> void:
	var at: Array[Vector3] = []
	for corner: Vector3 in CORNERS:
		at.append(centre + basis * (corner * size))
	for face: Array in FACES:
		quad(key, at[face[0]], at[face[1]], at[face[2]], at[face[3]], colour)


## An upright prism of `sides` round `base`: `size` is its radius at the bottom
## and its height, `top_radius` its radius at the top. A post, a pole, a pot, a
## well — or a cone at 0.
func column(
	key: StringName,
	base: Vector3,
	size: Vector2,
	sides: int,
	colour: Color,
	top_radius: float = -1.0
) -> void:
	var radius := size.x
	var upper := radius if top_radius < 0.0 else top_radius
	var top := base + Vector3(0.0, size.y, 0.0)
	for i: int in sides:
		var a := _spoke(i, sides)
		var b := _spoke(i + 1, sides)
		quad(key, base + b * radius, base + a * radius, top + a * upper, top + b * upper, colour)
		if upper > 0.0:
			tri(key, top, top + b * upper, top + a * upper, colour)


## A roof of four slopes over the rectangle `size` centred on `centre`, rising
## `rise` to a ridge along its longer side — or to a point when it is square.
func hip_roof(key: StringName, centre: Vector3, size: Vector2, rise: float, colour: Color) -> void:
	var half := size * 0.5
	var ridge := maxf(half.x - half.y, 0.0)
	var along_z := maxf(half.y - half.x, 0.0)
	var a := centre + Vector3(-half.x, 0.0, -half.y)
	var b := centre + Vector3(half.x, 0.0, -half.y)
	var c := centre + Vector3(half.x, 0.0, half.y)
	var d := centre + Vector3(-half.x, 0.0, half.y)
	var north := centre + Vector3(-ridge, rise, -along_z)
	var south := centre + Vector3(ridge, rise, along_z)
	if north.is_equal_approx(south):
		# Square: four slopes to one point, and no ridge to be a sliver of.
		tri(key, b, a, north, colour)
		tri(key, c, b, north, colour)
		tri(key, d, c, north, colour)
		tri(key, a, d, north, colour)
	elif ridge > 0.0:
		quad(key, b, a, north, south, colour)
		quad(key, d, c, south, north, colour)
		tri(key, a, d, north, colour)
		tri(key, c, b, south, colour)
	else:
		quad(key, a, d, south, north, colour)
		quad(key, c, b, north, south, colour)
		tri(key, b, a, north, colour)
		tri(key, d, c, south, colour)


static func _spoke(i: int, sides: int) -> Vector3:
	var turn := TAU * float(i) / float(sides)
	return Vector3(cos(turn), 0.0, sin(turn))


## Every key's parts as one mesh under `parent`, drawn with `materials.of(key)`.
## Null when nothing was batched.
func commit(parent: Node3D, materials: WorldMaterials, node_name: String) -> MeshInstance3D:
	if _surfaces.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for key: StringName in _surfaces:
		var surface := _surfaces[key] as Surface
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_COLOR] = surface.colours
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials.of(key))
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func triangle_count() -> int:
	var total := 0
	for key: StringName in _surfaces:
		total += (_surfaces[key] as Surface).vertices.size() / 3
	return total


## The vertices batched under `key`, for a test to measure.
func vertices_of(key: StringName) -> PackedVector3Array:
	var surface := _surfaces.get(key) as Surface
	return surface.vertices if surface != null else PackedVector3Array()


## The normals batched under `key`, one per vertex.
func normals_of(key: StringName) -> PackedVector3Array:
	var surface := _surfaces.get(key) as Surface
	return surface.normals if surface != null else PackedVector3Array()


func keys() -> Array:
	return _surfaces.keys()
