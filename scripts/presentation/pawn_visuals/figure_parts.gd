## **THE MESHES AND PAINTS EVERY FIGURE SHARES.** US-0109. CLIENT ONLY.
##
## Ninety figures of sixteen parts each are fourteen hundred mesh instances. Built
## one mesh and one material apiece — which is what the capsule figure did — they
## are fourteen hundred draws; **shared, the renderer draws each shape once for
## every figure wearing it.** So a mesh is made once per shape and a material once
## per colour, for the life of the process.
##
## Low in polygons on purpose: ART_BIBLE §5 gives a persona 8 000 triangles and
## ninety of them the screen at once. A figure here is about 1 500.
class_name FigureParts
extends RefCounted

## The figure's own neutrals. ART_BIBLE §3: everything that is not the identity
## hue lives in a desaturated warm range — skin, hair, leather, linen, dark cloth.
const SKIN := Color(0.74, 0.6, 0.52)
const HAIR := Color(0.23, 0.19, 0.17)
const LEATHER := Color(0.36, 0.28, 0.21)
const LINEN := Color(0.78, 0.74, 0.66)
const DARK := Color(0.27, 0.26, 0.27)
const HOSE := Color(0.56, 0.52, 0.47)
const TIMBER := Color(0.45, 0.36, 0.28)
## What the fillers wear, one each. None is near a persona's hue.
const HOMESPUN: Array[Color] = [
	Color(0.5, 0.46, 0.42),
	Color(0.42, 0.42, 0.45),
	Color(0.58, 0.54, 0.48),
	Color(0.45, 0.4, 0.36),
	Color(0.52, 0.5, 0.52),
]

const RADIAL := 10

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## A limb: a capsule `radius` thick and `length` long, end to end.
static func limb(radius: float, length: float) -> Mesh:
	var key := "limb/%.3f/%.3f" % [radius, length]
	if not _meshes.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = maxf(length, radius * 2.0)
		mesh.radial_segments = RADIAL
		mesh.rings = 3
		_meshes[key] = mesh
	return _meshes[key]


static func ball(radius: float) -> Mesh:
	var key := "ball/%.3f" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = RADIAL + 2
		mesh.rings = 6
		_meshes[key] = mesh
	return _meshes[key]


static func block(size: Vector3) -> Mesh:
	var key := "block/%.3f/%.3f/%.3f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _meshes[key]


## A cone, drum or tube: `top` and `bottom` radii, `height` tall.
static func drum(top: float, bottom: float, height: float) -> Mesh:
	var key := "drum/%.3f/%.3f/%.3f" % [top, bottom, height]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = bottom
		mesh.height = height
		mesh.radial_segments = RADIAL + 2
		mesh.rings = 1
		_meshes[key] = mesh
	return _meshes[key]


## The one material every part of `colour` wears, on every figure.
static func paint(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.9
		_materials[key] = material
	return _materials[key]
