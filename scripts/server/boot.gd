## Entry point. THE ONLY branch between client and server topology.
##
## Lives in scripts/server/ rather than the scripts/ root because a script at
## the root belongs to no layer, and the layer rule is enforced by folder
## membership (test_folder_structure.gd).
##
## STUB — flag parsing and the real branch arrive in US-0012.
extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--server"):
		Log.info("boot: server mode (US-0012 wires server_root.tscn)")
	else:
		Log.info("boot: client mode (US-0012 wires client_root.tscn)")
