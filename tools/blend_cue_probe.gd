## **LOOK AT THE NET AND THE GREY.** US-0107, drawn 2026-10-06.
##
## `test_blend_cues.gd` proves which figures are greyed and how many nets are shown;
## it cannot say whether a faint honeycomb on the ground is *visible*, or whether
## "slightly greyed" still reads as the persona. Those are found by looking.
##
## It boots the real `client_root.tscn` with no server and feeds it what a server
## would: snapshots carrying a knot of four standing civilians and two people on a
## bench, `NET-S2C-CROWD-GROUPS` naming the knot, and the player's own
## `blend_state`. So it proves the drawing and nothing about the server's tags.
##
## Run it windowed:
##
## ```
## godot --path . res://tools/blend_cue_probe.tscn
## ```
extends Node

const CLIENT := "res://scenes/client_root.tscn"
const SETTLE := 60
## The district's west bench, from `VetraioLayout.BENCHES`, and its seats.
const BENCH := "BenchVetroWest"

var _root: Node = null
var _shots: Array[String] = []
var _tick := 1000
var _blend := BlendKind.Kind.NONE
var _civilians: Dictionary = {}
var _feeding := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like a missing net.")
		get_tree().quit(1)
		return
	_root = (load(CLIENT) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_root)
	for _i: int in SETTLE:
		await get_tree().process_frame
	_feeding = true
	await _sequence()
	print("")
	for line: String in _shots:
		print("  ", line)
	get_tree().quit()


func _sequence() -> void:
	var ahead := _ahead()
	var right := ahead.cross(Vector3.UP)
	var spot := _pawn().global_position + ahead * 6.0 + right * 2.5
	for i: int in 4:
		var turn := TAU * i / 4.0
		_civilians[i + 1] = spot + Vector3(cos(turn), 0.0, sin(turn)) * 0.9
	var pairs := PackedByteArray()
	for index: int in _civilians:
		pairs.append_array([index, BlendGroupTag.STANDING])
	Net.events.crowd.crowd_groups_received.emit(true, pairs)
	await _shot("knot", "a faint white honeycomb under the four standing figures", 1.0)
	_place(spot)
	_blend = BlendKind.Kind.POCKET
	await _shot("knot_blended", "me and the four slightly greyed, the hue still readable", 1.0)
	await _bench_shots()


## Two people on the district's west bench, then the player on its first seat.
func _bench_shots() -> void:
	var seats := _seats()
	_civilians = {5: seats[1], 6: seats[2]}
	# They hold the bench's second and third seats, as `LeanSpots` would say: the
	# seats follow the twelve lean spots in `MapData.static_props`.
	var first_seat := VetraioGround.stall_lean_points().size()
	Net.events.crowd.crowd_groups_received.emit(
		false,
		PackedByteArray(
			[5, BlendGroupTag.prop(first_seat + 1), 6, BlendGroupTag.prop(first_seat + 2)]
		)
	)
	_blend = BlendKind.Kind.NONE
	# The bench stands at the district's north edge facing the market: turn round to
	# look at it from the square, or the camera stands outside the map.
	var sampler := _root.get_node("InputSampler")
	sampler.set("_look_yaw", wrapf(float(sampler.get("_look_yaw")) + PI, -PI, PI))
	await get_tree().create_timer(0.3).timeout
	var ahead := _ahead()
	_place(seats[1] - ahead * 4.5)
	await _shot("bench", "a net under the bench seats, nobody greyed", 1.0)
	_place(seats[0])
	_blend = BlendKind.Kind.PROP_STATIC
	await _shot("bench_blended", "me and the two on my bench greyed", 1.0)


## Where the camera looks, flat.
func _ahead() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var forward := -camera.global_transform.basis.z if camera != null else Vector3.FORWARD
	return Vector3(forward.x, 0.0, forward.z).normalized()


func _seats() -> Array:
	var out: Array = []
	for row: Array in VetraioGround.bench_seat_points():
		if str(row[0]).begins_with(BENCH):
			out.append(Vector3(float(row[1]), VetraioLayout.STREET_Y, float(row[2])))
	return out


func _pawn() -> Node3D:
	return _root.get_node("World/PawnLocal") as Node3D


func _place(at: Vector3) -> void:
	(_root.get_node("LocalPawnDriver") as LocalPawnDriver).ctx.position = at
	_pawn().global_position = at


## **A SNAPSHOT EVERY PHYSICS FRAME**, as a server would send one every tick, so
## `NpcView` has samples on both sides of the moment it draws.
func _physics_process(_delta: float) -> void:
	if not _feeding:
		return
	_tick += 1
	var snapshot := Snapshot.new()
	snapshot.server_tick = _tick
	snapshot.own_position = _pawn().global_position
	snapshot.blend_state = _blend
	for index: int in _civilians:
		snapshot.add_npc(index, _civilians[index], 0.0, 0, 0)
	Net.snapshot_received.emit(snapshot)
	_dress()


## Figures in a persona's hue, so the grey can be judged against a colour.
func _dress() -> void:
	var crowd := _root.get_node_or_null("ClientNet/NpcView") as NpcView
	for index: int in _civilians:
		var body := crowd.body_of(index) if crowd != null else null
		if body != null:
			body.dress(Ids.PERSONA_LUCERNA)
	var mine := _root.get_node_or_null("World/PawnLocal/PersonaVisuals") as PersonaBody
	if mine != null:
		mine.dress(Ids.PERSONA_VETRAIO)


func _shot(id: String, expect: String, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	var path := "user://blend_cue_%s.png" % id
	get_tree().root.get_texture().get_image().save_png(path)
	_shots.append("%s — %s" % [ProjectSettings.globalize_path(path), expect])
