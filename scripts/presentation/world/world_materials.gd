## **THE DISTRICT'S MATERIALS, BUILT FROM ITS PALETTE.** ADR-0026. CLIENT ONLY.
##
## Ten of them for the whole district: eight kinds of one surface shader, the
## ground and the water. A building's own colour is an *instance* parameter on the
## shared plaster, so forty walls are one material and batch as one.
class_name WorldMaterials
extends RefCounted

## The surface shader's `kind`, in its order.
enum Kind { PLASTER, COURSED, STONE, TIMBER, CLOTH, ROOF, IRON, GLASS }

const SURFACE := "res://assets/procedural/shaders/world_surface.gdshader"
const GROUND := "res://assets/procedural/shaders/world_ground.gdshader"
const WATER := "res://assets/procedural/shaders/world_water.gdshader"

## The ground shader's `pattern`.
const SETTS := 0.0
const PAVING := 1.0
const BOARDS := 2.0

## Batch keys, which are also the names the materials are held under.
const PLASTER := &"plaster"
const CLIMB := &"climb"
const STONE := &"stone"
const TIMBER := &"timber"
const CLOTH := &"cloth"
const ROOF := &"roof"
const IRON := &"iron"
const GLASS := &"glass"

var ground: ShaderMaterial
var water: ShaderMaterial

var _by_key: Dictionary = {}


func _init(palette: WorldPalette) -> void:
	var p := palette
	_by_key[PLASTER] = _surface(Kind.PLASTER, WorldPalette.PLAIN, p.brick, p)
	_by_key[CLIMB] = _surface(Kind.COURSED, p.climb_stone, p.climb_joint, p)
	_by_key[STONE] = _surface(Kind.STONE, WorldPalette.PLAIN, p.climb_joint, p)
	_by_key[TIMBER] = _surface(Kind.TIMBER, WorldPalette.PLAIN, p.timber_dark, p)
	_by_key[CLOTH] = _surface(Kind.CLOTH, p.linen, WorldPalette.PLAIN, p)
	_by_key[ROOF] = _surface(Kind.ROOF, p.roof_tile, p.terrace_joint, p)
	_by_key[IRON] = _surface(Kind.IRON, p.iron, p.iron, p)
	_by_key[GLASS] = _surface(Kind.GLASS, p.glass, p.glass, p)
	ground = ShaderMaterial.new()
	ground.shader = load(GROUND) as Shader
	ground.set_shader_parameter(&"stone_a", p.ground_a)
	ground.set_shader_parameter(&"stone_b", p.ground_b)
	ground.set_shader_parameter(&"joint", p.ground_joint)
	ground.set_shader_parameter(&"band", p.ground_band)
	ground.set_shader_parameter(&"board", p.board)
	ground.set_shader_parameter(&"side", p.quay)
	water = ShaderMaterial.new()
	water.shader = load(WATER) as Shader
	water.set_shader_parameter(&"deep", p.water_deep)
	water.set_shader_parameter(&"shallow", p.water_shallow)


## The material a batch key is drawn with.
func of(key: StringName) -> ShaderMaterial:
	return _by_key.get(key) as ShaderMaterial


func keys() -> Array:
	return _by_key.keys()


func _surface(kind: Kind, base: Color, second: Color, palette: WorldPalette) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SURFACE) as Shader
	material.set_shader_parameter(&"kind", int(kind))
	material.set_shader_parameter(&"base_colour", base)
	material.set_shader_parameter(&"second_colour", second)
	material.set_shader_parameter(&"top_colour", palette.terrace_tile)
	material.set_shader_parameter(&"top_joint", palette.terrace_joint)
	return material
