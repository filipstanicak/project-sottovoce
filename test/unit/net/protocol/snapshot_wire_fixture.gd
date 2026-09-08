## Distinct values in every wire field, captured before the snapshot split.
extends RefCounted


static func full() -> Snapshot:
	var snap := Snapshot.new()
	snap.server_tick = 0x12345678
	snap.last_acked_seq = 0x2345
	snap.flags = 165
	snap.baseline_age = 9
	snap.present_slots = 18
	snap.own_position = Vector3(12.25, -3.5, 98.75)
	snap.own_velocity = Vector3(-2.25, 0.125, 4.5)
	snap.own_state = PawnStateId.SPRINT
	snap.own_state_timer = 900
	snap.own_grounded = true
	snap.suspicion = 87.0
	snap.tier = 2
	snap.active_sources = 21
	snap.cooldown_a_tick = 1200
	snap.cooldown_b_tick = 65535
	snap.blend_state = 9
	snap.kill_ready = true
	snap.stun_ready = false
	snap.hunt_fraction = 22
	snap.hunted_fraction = 199
	snap.bearing = 200
	snap.distance_bucket = 44
	snap.lock_fraction = 128
	snap.portrait_revealed = true
	snap.phase = 3
	snap.ticks_remaining = 7200
	snap.multiplier = 2
	_records(snap)
	return snap


static func _records(snap: Snapshot) -> void:
	snap.add_remote(2, Vector3(60.0, 3.5, -12.0), PI / 2.0, PawnStateId.STROLL, 33, 2)
	snap.add_remote(5, Vector3(-4.25, 1.75, 8.5), -PI / 4.0, PawnStateId.LUNGING, 17, 1)
	snap.add_npc(17, Vector3(-4.0, 3.5, 77.5), PI, 5, 20)
	snap.add_npc(89, Vector3(11.25, 0.75, -20.5), -PI / 2.0, 2, 7)


static func limits() -> Snapshot:
	var snap := full()
	snap.baseline_age = 999
	snap.hunt_fraction = -1
	snap.hunted_fraction = 999
	snap.own_state = &""
	snap.own_grounded = false
	snap.kill_ready = false
	snap.stun_ready = true
	snap.portrait_revealed = false
	snap.remote_pawns.clear()
	snap.npcs.clear()
	snap.add_remote(1, Vector3(-500.0, 500.0, 0.0), TAU, &"", 127, 7)
	snap.add_npc(255, Vector3(500.0, 100.0, -500.0), TAU, 15, 63)
	return snap
