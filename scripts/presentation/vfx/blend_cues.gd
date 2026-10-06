## **THE NET UNDER EVERY GROUP AND BENCH, AND THE GREY OVER ONE'S OWN.** US-0107.
## CLIENT ONLY.
##
## Reported from the controls on 2026-10-06: *the crowd feels right, but nothing
## says where I can blend or whether I am.* The server knew both and no client drew
## either. The owner's reading of the reference, from playing it: a faint white
## honeycomb lies on the ground under every group and every bench, all the time,
## and a blended player sees themselves and the civilians of their group slightly
## greyed — on their own screen only, so they know whom the blend rests on.
##
## **THE NET IS THE SAME ON EVERY SCREEN, AND THE GREY IS ON ONE.** The net is
## drawn from `NET-S2C-CROWD-GROUPS`, which every client is told alike and which
## the server computes from civilians alone, so it never marks a player. The grey
## is drawn from this player's own `blend_state` and touches no other screen.
class_name BlendCues
extends Node3D

## A faint white honeycomb in world space, fading out toward the disc's rim, so
## neighbouring nets join without a seam and a moving group does not drag its
## pattern along. Cells of `cell` metres. **Each line carries a faint dark seam**
## (`Palette.blend_net_seam`), measured necessary: on the greybox's sunlit floor a
## white line alone vanished (`tools/blend_cue_probe.tscn`, first run).
const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 line_colour : source_color;
uniform vec4 seam_colour : source_color;
uniform float cell = 0.45;
uniform float line_width = 0.03;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 s = vec2(1.0, 1.7320508);
	vec2 p = world_xz / cell;
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 g = abs(dot(a, a) < dot(b, b) ? a : b);
	float edge = 0.5 - max(dot(g, vec2(0.5, 0.8660254)), g.x);
	float line = 1.0 - smoothstep(0.0, line_width / cell, edge);
	float halo = 1.0 - smoothstep(0.0, 3.0 * line_width / cell, edge);
	float rim = 1.0 - smoothstep(0.6, 1.0, length(UV - vec2(0.5)) * 2.0);
	float lit = line_colour.a * line;
	float shade = seam_colour.a * (halo - line);
	float alpha = max(lit, shade);
	ALBEDO = mix(seam_colour.rgb, line_colour.rgb, lit / max(alpha, 0.0001));
	ALPHA = alpha * rim;
}
"""

## Lifted off the ground so the net does not flicker into it.
const LIFT := 0.03
## How often the standing nets are recomputed when no tag changed. Standing
## civilians do not move; the pass costs about a millisecond for forty of them.
const STANDING_REFRESH := 0.25

## Each NPC's `BlendGroupTag`, by index. A `u8` index, so 256.
var tags := PackedByteArray()

## Where the net's colours come from (UI_UX_SPEC §7): the HUD's palette, handed
## over by the client root, so a colourblind palette can move them.
var palette: Palette = Palette.fallback()

var _npcs: NpcView = null
var _me: Node3D = null
var _my_body: PersonaBody = null
var _props: Array = []
var _kind: int = BlendKind.Kind.NONE
var _material := ShaderMaterial.new()
var _group_nets: Array[MeshInstance3D] = []
var _greyed: Dictionary = {}
var _standing_nets: Array = []
var _standing_age := INF


func _ready() -> void:
	tags.resize(256)
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_material.set_shader_parameter(&"line_colour", palette.blend_net)
	_material.set_shader_parameter(&"seam_colour", palette.blend_net_seam)
	Net.events.crowd.crowd_groups_received.connect(apply_groups)
	EventBus.blend_state_changed.connect(_on_blend_state)


## What to draw over: the crowd, this player's pawn and body, and the map's
## static props — every bench seat and stall counter.
func bind(npcs: NpcView, me: Node3D, my_body: PersonaBody, props: Array) -> void:
	_npcs = npcs
	_me = me
	_my_body = my_body
	_props = props
	for prop: Vector3 in _props:
		_net(prop + Vector3.UP * LIFT, BlendCueRules.PROP_NET_RADIUS)


func apply_groups(full: bool, pairs: PackedByteArray) -> void:
	if full:
		tags.fill(BlendGroupTag.NONE)
	for i: int in range(0, pairs.size() - 1, 2):
		tags[pairs[i]] = pairs[i + 1]
	_standing_age = INF


func _on_blend_state(kind: int) -> void:
	_kind = kind


func _process(delta: float) -> void:
	var drawn := _drawn()
	_standing_age += delta
	if _standing_age >= STANDING_REFRESH:
		_standing_age = 0.0
		_standing_nets = BlendCueRules.standing_nets(tags, drawn)
	_draw_groups(drawn)
	_grey(drawn)


## Where this client draws each NPC it holds.
func _drawn() -> Dictionary:
	var out: Dictionary = {}
	if _npcs == null:
		return out
	for index: int in _npcs.indices():
		var body := _npcs.body_of(index)
		if body != null and body.is_inside_tree():
			out[index] = body.global_position
	return out


func _draw_groups(drawn: Dictionary) -> void:
	var nets := BlendCueRules.walking_nets(tags, drawn) + _standing_nets
	while _group_nets.size() < nets.size():
		_group_nets.append(_net(Vector3.ZERO, 1.0))
	for i: int in _group_nets.size():
		var shown := i < nets.size()
		_group_nets[i].visible = shown
		if shown:
			_group_nets[i].position = (nets[i][0] as Vector3) + Vector3.UP * LIFT
			_group_nets[i].scale = Vector3.ONE * float(nets[i][1]) * 2.0


## **THIS PLAYER AND THEIR GROUP, GREYED WHILE BLENDED.** Not inside a hiding
## spot, where the player is not drawn at all.
func _grey(drawn: Dictionary) -> void:
	var blended := BlendKind.is_blend(_kind) and _kind != BlendKind.Kind.PROP_CONCEAL
	var wanted: Dictionary = {}
	if blended and _me != null:
		var group := BlendCueRules.greyed(_kind, _me.global_position, tags, drawn, _props)
		for index: int in group:
			wanted[index] = true
	for index: int in _greyed.keys():
		if not wanted.has(index):
			_set_grey(index, false)
	for index: int in wanted:
		_set_grey(index, true)
	_greyed = wanted
	if _my_body != null:
		_my_body.set_greyed(blended)


func _set_grey(index: int, on: bool) -> void:
	var body := _npcs.body_of(index) if _npcs != null else null
	if body != null and is_instance_valid(body):
		body.set_greyed(on)


func _net(at: Vector3, radius: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var net := MeshInstance3D.new()
	net.mesh = plane
	net.material_override = _material
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	net.position = at
	net.scale = Vector3.ONE * radius * 2.0
	add_child(net)
	return net
