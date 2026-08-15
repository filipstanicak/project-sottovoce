## **THE DUMB LAYER UNDER THE STATE MACHINE.** TDD-08 §1, US-0041. SERVER ONLY.
##
## **IT KNOWS NOTHING ABOUT BRAIN STATES, AND THAT IS THE ACCEPTANCE CRITERION.**
## Every entry point here takes a *point* and a *speed*. Nothing takes a state,
## an event or a brain, and `test_steering_knows_no_states.gd` scans this file to
## keep it that way. The reason is not tidiness: the moment steering can see a
## state, the answer to "why did that NPC walk there" lives in two files, and the
## crowd is an information channel a player is expected to read correctly.
##
## **THE ONE PLACE PERMITTED TO CACHE TUNING VALUES**, TDD-05 §4.3: ninety agents
## looking four values up through an autoload every tick measured above the
## ADR-0005 threshold. The cache refreshes on `Tuning.reloaded`, so a hot reload
## still reaches it.
##
## **MOVEMENT INTEGRATES AT THE PHYSICS RATE; STEERING DECIDES AT THE NET TICK.**
## `NavigationAgent3D` emits `velocity_computed` **every physics frame** once
## avoidance is enabled — measured, not assumed: nine callbacks over ten frames
## after a single `set_velocity()`. So the safe velocity is applied there, at 60
## Hz, and the desired velocity is chosen by `CrowdDirector` at 30 Hz. Moving the
## body from the director instead would halve every NPC's speed in silence,
## because `move_and_slide()` always integrates by the *physics* delta — and an
## NPC stroll that is not exactly `TUN-SPEED-BLENDWALK` is the discriminator
## invariant 1 exists to forbid.
class_name Steering
extends RefCounted

## How fast a standing NPC may be shoved aside by the crowd around it. Not a
## gameplay constant: nothing reads it, no state travels at it, and it exists so
## that RVO has a non-zero budget to resolve an overlap with. A tunable here
## would be a number a designer could change and see nothing happen.
const IDLE_SHUFFLE := 0.1

## Cached from `Tuning`. Refreshed by `refresh()` and by nothing else.
var stroll_speed: float = 0.0
var flee_speed: float = 0.0
var arrive_radius: float = 0.0
var neighbour_distance: float = 0.0


func _init() -> void:
	refresh()


## Re-read every cached value. Connected to `Tuning.reloaded` by the director,
## so a designer's hot reload is not silently ignored by the crowd.
func refresh() -> void:
	stroll_speed = Tuning.crowd.npc_speed_stroll
	flee_speed = Tuning.crowd.npc_speed_flee
	arrive_radius = Tuning.crowd.anchor_arrive_radius
	neighbour_distance = Tuning.suspicion.blend_pocket_radius


## Set an agent up from the body it belongs to and from tuning. Called once per
## NPC, at allocation.
##
## **THE AVOIDANCE RADIUS COMES OFF THE CAPSULE**, not off the navmesh bake. They
## are different quantities that happen to be close: the bake's 0.4 insets the
## walkable surface from walls, and this one is how much room an NPC asks other
## agents to leave it. Reading the capsule also means the "a clone's collider
## matches a player's" property propagates here for free.
##
## **`active` SWITCHES AVOIDANCE, AND AN INACTIVE AGENT MUST NOT HAVE IT.**
## `PROCESS_MODE_DISABLED` takes an inactive NPC out of the *physics* world —
## measured, with a control run that blocked — but it does not unregister the
## agent from the navigation server. Twelve unused bodies sit stacked at the
## origin in a four-player match, and left avoidance-enabled they would be twelve
## invisible things for the crowd to walk around in one corner of the district.
func configure(body: CharacterBody3D, agent: NavigationAgent3D, active: bool) -> void:
	var capsule := _capsule_of(body)
	agent.radius = capsule.x
	agent.height = capsule.y
	# An initial value only. **`max_speed` IS RESET ON EVERY `drive()`**, and the
	# reason is in that function's note.
	agent.max_speed = flee_speed
	# **WHO AN NPC AVOIDS IS WHO IT WOULD SHARE A POCKET WITH.** Godot's default
	# is 50 m, which asks every agent to consider the whole district; the blend
	# pocket radius is the distance at which the game already considers two people
	# to be standing together.
	agent.neighbor_distance = neighbour_distance
	# One capsule width from a waypoint is close enough to move on to the next.
	agent.path_desired_distance = capsule.x * 2.0
	agent.target_desired_distance = arrive_radius
	agent.avoidance_enabled = active


## Connect an agent's avoidance result to its body. Idempotent, because the pool
## outlives a match and the director is set up once per match.
func attach(body: CharacterBody3D, agent: NavigationAgent3D) -> void:
	# **THE BOUND CALLABLE IS THE ONE TO ASK ABOUT.** `is_connected` compares bound
	# arguments too, so checking the unbound method would answer "no" every time
	# and connect a second handler on every setup — an NPC moved twice per frame,
	# at double speed, with nothing in the log.
	var handler := _apply_safe_velocity.bind(body)
	if not agent.velocity_computed.is_connected(handler):
		agent.velocity_computed.connect(handler)


## Send an agent somewhere. A point, never a reason.
func aim(agent: NavigationAgent3D, goal: Vector3) -> void:
	agent.target_position = goal


## True once the agent is inside `target_desired_distance` of its goal — or once
## it has decided it cannot get there, which is the same thing to the caller.
func arrived(agent: NavigationAgent3D) -> bool:
	return agent.is_navigation_finished()


## Ask for `speed` toward the next point on the path. Horizontal only: y belongs
## to gravity and to the floor, and a desired velocity carrying the navmesh's own
## height would walk NPCs into the ground on every slope.
func drive(body: CharacterBody3D, agent: NavigationAgent3D, speed: float) -> void:
	# **RVO IS ALLOWED TO PICK ANY VELOCITY UP TO `max_speed`, NOT UP TO THE ONE
	# IT WAS ASKED FOR.** Left at the flee speed, a *strolling* NPC dodging a
	# neighbour would sidestep at up to 5 m/s: measured at 2.24 m/s against a
	# stroll of 1.4 before this line existed. That is a civilian moving faster than
	# a civilian can, which is precisely the discriminator invariant 1 exists to
	# forbid — and it would have shipped as "the clones look twitchy".
	#
	# The floor is not zero. An NPC standing still still has to be *shovable* by
	# the crowd around it, or a walking group would walk through an idle cluster;
	# a tenth of a metre per second is a shuffle, not a walk.
	agent.max_speed = maxf(speed, IDLE_SHUFFLE)
	if speed <= 0.0 or agent.is_navigation_finished():
		agent.set_velocity(Vector3.ZERO)
		return
	var toward := agent.get_next_path_position() - body.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.000001:
		agent.set_velocity(Vector3.ZERO)
		return
	agent.set_velocity(toward.normalized() * speed)


## The avoidance result, applied. **Runs on the physics frame, not the net tick**
## — see the class note.
##
## Gravity is here because the baked navmesh does **not** sit on the street: its
## surface rasterises to a whole number of `cell_height` voxels above the floor
## it was baked from, so an NPC snapped onto the mesh starts in the air. Without
## a fall it would stay there, and a crowd hovering a few centimetres up is a
## thing nobody notices until meshes land and every civilian is levitating.
func _apply_safe_velocity(safe: Vector3, body: CharacterBody3D) -> void:
	body.velocity.x = safe.x
	body.velocity.z = safe.z
	if body.is_on_floor():
		body.velocity.y = 0.0
	else:
		body.velocity.y -= Tuning.gravity / float(Engine.physics_ticks_per_second)
	body.move_and_slide()


## `(radius, height)` of the body's capsule. Falls back to the navmesh's agent
## dimensions when there is no capsule, which is a test double rather than a
## shipping NPC — a silent zero radius would disable avoidance entirely and look
## exactly like avoidance that does not work.
static func _capsule_of(body: CharacterBody3D) -> Vector2:
	for child: Node in body.get_children():
		var shape := child as CollisionShape3D
		if shape == null:
			continue
		var capsule := shape.shape as CapsuleShape3D
		if capsule != null:
			return Vector2(capsule.radius, capsule.height)
	return Vector2(VetraioLayout.NAV_AGENT_RADIUS, VetraioLayout.NAV_AGENT_HEIGHT)
