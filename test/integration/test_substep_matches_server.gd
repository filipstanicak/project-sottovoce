## **THE CLIENT AND THE SERVER LAND IN THE SAME PLACE.** ADR-0008, US-0028.
##
## The whole premise of prediction: the client simulates ahead, the server
## simulates the same inputs, and reconciliation only has to correct the
## difference. If there is no difference there is nothing to correct, and every
## dropped packet costs nothing.
##
## **BOTH SIDES ARE REAL HERE.** The client is `client_root.tscn` driven through
## the real `InputMap`; the server is `PawnHost` driving `pawn_server.tscn`. The
## commands are not synthesised — they are the ones the client's own sampler
## produced, handed to the server exactly as the wire would.
##
## A test that fed hand-built commands to both would prove the state machine is
## deterministic, which nobody doubts. This proves the two *code paths* agree,
## which is the thing that was one refactor away from being false: stepping the
## machine is only half a tick, and the other half — who owns position during a
## traversal, when gravity applies, what is written back from the body — lived in
## `LocalPawnDriver` alone until `PawnMotion` was extracted for this story.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"
const PEER := 1

var _root: Node
var _driver: LocalPawnDriver
var _host: PawnHost
var _ctx := MatchContext.new()


func before_each() -> void:
	_release_everything()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")

	_host = PawnHost.new()
	add_child_autofree(_host)
	_ctx.map = load("res://data/maps/map_vetraio.tres") as MapData
	_host.setup(_ctx)
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


## Put the server's pawn exactly where the client's is, then hand it every
## command the client samples. One command in, one substep out — the same
## contract `MatchDirector` enforces at the net tick.
func _mirror_the_client() -> void:
	_host.spawn(PEER)
	var server := _host.context_for(PEER)
	server.reset_for_spawn(_driver.ctx.position, _driver.ctx.yaw)
	(server.body as CharacterBody3D).global_position = server.position
	_driver.command_sampled.connect(
		func(command: InputCommand) -> void:
			_host.apply_input(PEER, command, 1.0 / Tuning.net.client_input_rate)
	)


func _run(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


func _divergence() -> float:
	return _driver.ctx.position.distance_to(_host.context_for(PEER).position)


func test_walking_forward_diverges_by_nothing_at_all() -> void:
	# **NOT "within the reconcile threshold".** `TUN-NET-RECONCILE-THRESHOLD` is
	# 10 cm and exists to absorb float noise and a tick of latency — it is not a
	# budget for the two sides doing different arithmetic. Given identical
	# commands they run identical code, so the honest assertion is zero.
	await _mirror_the_client()
	Input.action_press(&"input_move_forward")
	await _run(60)
	assert_gt(_driver.ctx.position.distance_to(Vector3.ZERO), 0.0, "the pawn never moved")
	assert_almost_eq(_divergence(), 0.0, 0.001, "the two peers walked to different places")


func test_it_stays_together_through_a_speed_change() -> void:
	# The acceleration curve is where a mismatched `dt` shows first: at
	# TUN-SPEED-ACCEL 18 m/s² a single tick of disagreement is centimetres, and it
	# never comes back.
	await _mirror_the_client()
	Input.action_press(&"input_move_forward")
	await _run(20)
	Input.action_press(&"input_run")
	await _run(40)
	Input.action_release(&"input_run")
	await _run(20)
	assert_almost_eq(_divergence(), 0.0, 0.001, "the speed ladder diverged the two peers")


func test_the_divergence_stays_inside_the_reconcile_threshold() -> void:
	# The criterion as US-0028 words it, asserted separately from the stronger
	# claim above — so that if float error ever does creep in, this file says
	# whether it matters or merely exists.
	await _mirror_the_client()
	Input.action_press(&"input_move_forward")
	Input.action_press(&"input_run")
	await _run(90)
	assert_lt(
		_divergence(),
		Tuning.net.reconcile_threshold,
		"the server and the client are further apart than reconciliation tolerates"
	)


func test_the_server_pawn_is_driven_by_the_same_motion_code() -> void:
	# Structural, and the reason the two agree at all. A second copy of
	# `apply()` would pass every test above on the day it was written and drift
	# the first time one copy was edited.
	var host_source := SourceScanner.read("res://scripts/server/pawn_host.gd")
	var client_source := SourceScanner.read("res://scripts/presentation/local_pawn_driver.gd")
	assert_true(host_source.contains("PawnMotion.advance("), "the server has its own motion code")
	assert_true(client_source.contains("PawnMotion.advance("), "the client has its own motion code")
	assert_false(client_source.contains("move_and_slide("), "the client still moves its own body")
