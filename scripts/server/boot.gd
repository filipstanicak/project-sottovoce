## Entry point. THE ONLY branch between client and server topology.
##
## Lives in scripts/server/ rather than the scripts/ root because a script at the
## root belongs to no layer, and the layer rule is enforced by folder membership
## (test_folder_structure.gd).
##
## Deliberately thin. It reads the command line, hands it to a pure parser, and
## swaps the scene. Everything that could hold a decision lives in LaunchConfig,
## where it is testable without an engine.
extends Node

const SERVER_ROOT := "res://scenes/server_root.tscn"
const CLIENT_ROOT := "res://scenes/client_root.tscn"


func _ready() -> void:
	var config := LaunchConfig.parse(OS.get_cmdline_user_args(), Tuning.match_rules.max_players)

	var problems := config.problems(Tuning.match_rules.min_players, Tuning.match_rules.max_players)
	if not problems.is_empty():
		for p: String in problems:
			Log.error(p, &"boot")
		Log.error("refusing to start on a bad command line", &"boot")
		get_tree().quit(1)
		return

	if config.seed_value >= 0:
		Log.info("seed %d (deterministic)" % config.seed_value, &"boot")
	for warning: String in config.warnings():
		Log.warn(warning, &"boot")

	if config.is_server:
		_start_server(config)
	else:
		_start_client(config)


func _start_server(config: LaunchConfig) -> void:
	Log.info("server on port %d, up to %d players" % [config.port, config.max_players], &"boot")
	# **THE SERVER DOES NOT INTERPOLATE, BECAUSE IT DOES NOT DRAW.**
	# `physics/common/physics_interpolation` is on for the client (US-0045), where
	# it took the share of rendered frames showing a new position from 37.7 % to
	# 99.9 %. A headless server renders nothing, so every interpolated transform it
	# computes is waste — measured at **0.27 ms of the server tick**, 1.58 to 1.85 ms
	# mean against an 8.0 ms budget.
	#
	# Set here rather than in `server_root.tscn` on purpose: this is a decision about
	# the **process**, and a test that instantiates the server scene must not flip a
	# global flag for whatever runs after it. Trap 4's family.
	get_tree().physics_interpolation = false
	if not Net.start_server(config.port, config.max_players):
		Log.error("refusing to start: the port is not available", &"boot")
		get_tree().quit(1)
		return
	# Deferred: _ready() runs while the tree is still adding children, and a
	# direct swap there fails with "parent node is busy". Nothing in the test
	# suite boots a scene, so this only ever shows up by launching the game.
	get_tree().change_scene_to_file.call_deferred(SERVER_ROOT)


func _start_client(config: LaunchConfig) -> void:
	Net.is_server = false
	if config.should_autoconnect():
		Log.info("client joining %s directly" % config.connect_address, &"boot")
		Net.join(config.connect_host(), config.connect_port())
	else:
		Log.info("client, menu", &"boot")
	get_tree().change_scene_to_file.call_deferred(CLIENT_ROOT)
