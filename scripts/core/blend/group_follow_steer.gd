## **WALKING A PLAYER ALONG WITH THEIR WALKING GROUP.** US-0107. PURE.
##
## The reference takes a player who joins a group over: they walk with it, in its
## pace and on its route, until they walk out (the owner, 2026-10-09; a player
## guide: *"your persona will be taken over by the AI and will walk automatically
## in the AI path"*). Until then a player here had to match a 1.4 m/s slot by hand
## within `TUN-BLEND-GROUP-SLOT-TOLERANCE`, 0.8 m, and the blend broke the moment
## they looked round.
##
## **IT STEERS BY WRITING THE COMMAND, AND NOTHING ELSE.** The server still judges
## the slot tolerance exactly as before; the client only produces the movement a
## player holding the stick perfectly would. A command is what the server simulates
## and what a replay re-feeds, so the prediction cannot drift from this.
class_name GroupFollowSteer
extends RefCounted

## How hard the gap to the slot is closed, per second. A slot 0.4 m away asks for
## 0.8 m/s on top of the group's own pace.
const GAIN := 2.0
## Below this wanted speed the player stands rather than shuffles.
const DEADBAND := 0.05
## The share of stroll the steering may use to catch up, so it never touches
## `TUN-BLEND-BREAK-ON-SPEED`, which equals stroll and breaks the blend it serves.
const HEADROOM := 0.9


## `[move, slow]` for a player at `here` whose slot is at `slot`, moving at
## `slot_velocity`, with the command landing `lead` seconds after the slot was
## measured. `move` is in the camera's frame at `look_yaw`, as every command's is.
static func steer(
	here: Vector3, slot: Vector3, slot_velocity: Vector3, lead: float, look_yaw: float
) -> Array:
	var aim := slot + slot_velocity * lead
	var want := (
		Vector2(slot_velocity.x, slot_velocity.z) + Vector2(aim.x - here.x, aim.z - here.z) * GAIN
	)
	var cap := Tuning.movement.stroll * HEADROOM
	if want.length() > cap:
		want = want.normalized() * cap
	if want.length() < DEADBAND:
		return [Vector2.ZERO, true]
	var slow := want.length() <= Tuning.movement.blend_walk
	var stick := want / (Tuning.movement.blend_walk if slow else Tuning.movement.stroll)
	# The pawn's frame at `look_yaw`, as `ProbeLayout.forward` and `right` define it:
	# forward (sin, cos) and right (-cos, sin) in x and z.
	var forward := Vector2(sin(look_yaw), cos(look_yaw))
	var right := Vector2(-cos(look_yaw), sin(look_yaw))
	return [Vector2(stick.dot(right), stick.dot(forward)), slow]
