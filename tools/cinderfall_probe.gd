## **LOOK AT THE CINDER CLOUD.** US-0067, drawn 2026-09-03.
##
## Every assertion in `test_cinderfall_view.gd` is about radii, centres and
## lifetimes, and **not one of them can tell you whether the thing is legible** —
## which is the gap that found an invisible tier indicator, a cone that read as a
## needle and a vignette that tinted the whole frame. Those were all found by
## looking, and none of them by a test.
##
## It boots the real `client_root.tscn` and emits `EVT-ABILITY-STARTED` on the bus,
## which is exactly the path a real tell drives — **no server and no wire**, so
## what this proves is the drawing and nothing about the netcode.
##
## Run it windowed:
##
## ```
## godot --path . res://tools/cinderfall_probe.tscn
## ```
extends Node

const CLIENT := "res://scenes/client_root.tscn"
const SETTLE := 60

var _root: Node = null
var _shots: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	# **HEADLESS RENDERS NOTHING**, and a blank PNG reads exactly like a cloud that
	# was never drawn — trap 13's family, and `persona_lineup.gd`'s own refusal.
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like a missing cloud.")
		get_tree().quit(1)
		return
	_root = (load(CLIENT) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_root)
	for _i: int in SETTLE:
		await get_tree().process_frame
	var view: CinderfallView = _root.get_node_or_null("World/CinderfallView")
	if view == null:
		print("REFUSING: client_root.tscn has no CinderfallView, so there is nothing to draw.")
		get_tree().quit(1)
		return
	await _sequence(view)
	print("")
	for line: String in _shots:
		print("  ", line)
	get_tree().quit()


func _sequence(view: CinderfallView) -> void:
	var here := _pawn_position()
	var data := Tuning.ability_data(Ids.ABIL_CINDERFALL)
	# **AIMED LONG AND CLAMPED TO THE FEET.** `TUN-CINDERFALL-THROW-RANGE` is 0.0
	# since 2026-09-03, so `AbilityRules.aim` puts every cast underfoot however far
	# the client asked — and this probe asks for the old 8 m deliberately, because a
	# probe that aims at zero would look right even if the throw came back.
	var asked := here + Vector3(0.0, 0.0, 8.0)
	var landed := here + AbilityRules.aim(here, asked - here, Vector3.FORWARD, 0.0).direction * 0.0
	EventBus.ability_started.emit(1, Ids.ABIL_CINDERFALL, here, landed)
	print("asked for a throw to ", asked, "   it lands at ", landed)
	await _shot("windup", "NO cloud — the pot is still in the air", data.cast_time * 0.4)
	print("clouds during the wind-up: ", view.live_count())
	# **THE CAMERA IS INSIDE IT, AND THAT IS THE POINT NOW.** The arm sits 2.6 m
	# behind the pawn and the cloud is `TUN-CINDERFALL-RADIUS` 5.0 m, so a caster is
	# always within their own smoke — the ability blinds whoever uses it.
	await _shot("burst", "the caster INSIDE their own ash — the district must be unreadable", 0.4)
	print("clouds after the burst:    ", view.live_count())
	await _shot("gone", "NOTHING — the cloud is out and the street is back", data.duration)
	print("clouds after the duration: ", view.live_count())


func _pawn_position() -> Vector3:
	var pawn := _root.get_node_or_null("World/PawnLocal") as Node3D
	return pawn.global_position if pawn != null else Vector3.ZERO


## **SECONDS, NOT FRAMES, AND THE FIRST VERSION COUNTED FRAMES.** It waited 46 of
## them for a 0.45 s wind-up on the assumption of 60 fps, this machine renders far
## faster than that, and it reported **0 clouds at the burst and 1 after the
## duration** — which reads exactly like a view that draws everything one beat
## late. An instrument wrong in a plausible direction is worse than no instrument;
## third one this session.
func _shot(id: String, expect: String, seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout
	var path := "user://cinderfall_%s.png" % id
	get_tree().root.get_texture().get_image().save_png(path)
	_shots.append("%s — %s" % [ProjectSettings.globalize_path(path), expect])
