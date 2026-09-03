## **THE WIND-UP, THE BURST, AND WHAT INTERRUPTING IT COSTS.** US-0070,
## GDD-04 §3.4, TDD-09 §1.
##
## **THE WIND-UP IS THE ASSERTION THIS FILE EXISTS FOR.** `TUN-LUNGE-WINDUP`
## 0.25 s was in `lunge.tres` with **no reader anywhere** — `_cast_ticks` read
## `cast_time` alone and said in a comment that Lunge had none, which is true of
## the field and false of the ability. Without it the dash bursts on the press
## tick, design law 3's *perceivable chance to react* is gone, and GDD-04 §3.4's
## *"a prepared defender ALWAYS beats a Lunge"* becomes false — 0.92 s of
## telegraphed approach is 0.67 s and undodgeable.
extends GutTest

const A := 81
const B := 82

var _system: AbilitySystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []


func before_each() -> void:
	_machines.clear()
	_ctx = MatchContext.new()
	_ctx.tick = 300
	_system = AbilitySystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	_place(A)
	_system.loadout[A] = [Ids.ABIL_LUNGE]


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


func _place(peer: int) -> PawnContext:
	var machine := PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		machine.register(script.new())
	_machines.append(machine)
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	machine.spawn_into(pawn, PawnStateId.IDLE)
	_ctx.pawn_contexts[peer] = pawn
	_ctx.pawn_machines[peer] = machine
	return pawn


func _press(direction := Vector3(0.0, 0.0, 1.0)) -> void:
	_system.report_request(A, 0, Vector3.ZERO, direction * 6.0)
	_system.tick(_ctx, MatchContext.net_dt())


## **THE `pawn` STAGE THEN THE `abilities` STAGE, IN `SystemOrder`'s OWN ORDER.**
## Stepping only the system is what the first version of this file did, and the
## dash never ended: `LungingState` is driven by `PawnMotion` at the `pawn` stage,
## so with nothing stepping the machine the pawn stayed `Lunging` forever and
## `LungeEffect.end` correctly refused to queue an arrival for it. **The fixture
## was wrong and the guard was right** — which is the shape worth keeping, so
## `test_a_dash_still_running_asks_for_nothing` asserts it deliberately below.
func _advance(ticks: int, step_the_pawn: bool = true) -> void:
	var command := InputCommand.new()
	for _i: int in ticks:
		_ctx.tick += 1
		if step_the_pawn:
			var machine := _ctx.pawn_machines[A] as PawnStateMachine
			var pawn := _ctx.pawn_contexts[A] as PawnContext
			for _sub: int in 2:
				machine.step(pawn, command, 1.0 / Tuning.net.client_input_rate)
		_system.tick(_ctx, MatchContext.net_dt())


func _state() -> StringName:
	return (_ctx.pawn_contexts[A] as PawnContext).state_id


# --- the wind-up ----------------------------------------------------------


func test_the_windup_has_a_reader_at_all() -> void:
	# **THE PREMISE, AND IT IS THE DEFECT THIS STORY FOUND.** Every assertion below
	# is satisfied by an ability that bursts instantly, so this is what stops the
	# file passing over a wind-up nobody honours.
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	assert_gt(data.windup, 0.0, "TUN-LUNGE-WINDUP is not in the resource")
	assert_almost_eq(
		AbilityRules.windup_of(data), data.windup, 0.0001, "the wind-up field has no reader"
	)


func test_the_dash_does_not_begin_on_the_press_tick() -> void:
	_press()
	assert_eq(_system.activations, 1, "the press was refused")
	assert_eq(_state(), PawnStateId.IDLE, "the dash burst with no telegraph at all")


func test_the_dash_begins_when_the_windup_elapses() -> void:
	_press()
	_advance(Tuning.ticks(&"TUN-LUNGE-WINDUP"))
	assert_eq(_state(), PawnStateId.LUNGING, "the wind-up never ended")


## `cast_time` and `windup` are two fields of one class holding four abilities'
## values — `AbilityRules.reach_of`'s rule, in a second place. Whichever an
## ability populates is its wind-up.
func test_an_ability_that_uses_cast_time_still_winds_up() -> void:
	var cinder := Tuning.ability_data(Ids.ABIL_CINDERFALL)
	assert_almost_eq(
		AbilityRules.windup_of(cinder),
		cinder.cast_time,
		0.0001,
		"reading `windup` broke the abilities that use `cast_time`"
	)


## The dash lasts `distance / speed`, so an effect whose lifetime came from a
## stored `duration` would end one tick after it began — `lunge.tres` has none.
func test_the_effect_lives_as_long_as_the_dash() -> void:
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	assert_eq(data.duration, 0.0, "Lunge gained a stored duration that can contradict the two")
	assert_almost_eq(
		AbilityRules.duration_of(data),
		data.distance / data.speed,
		0.0001,
		"the dash duration stopped being derived"
	)


# --- the burst ------------------------------------------------------------


func test_the_burst_sets_the_locked_direction_as_velocity() -> void:
	_press(Vector3(1.0, 0.0, 0.0))
	_advance(Tuning.ticks(&"TUN-LUNGE-WINDUP"))
	var pawn := _ctx.pawn_contexts[A] as PawnContext
	var flat := Vector3(pawn.velocity.x, 0.0, pawn.velocity.z)
	assert_almost_eq(flat.length(), LungingState.dash_speed(), 0.01, "the dash has no speed")
	assert_almost_eq(flat.normalized().x, 1.0, 0.001, "the dash went somewhere else")


## **AIMING AT THE SKY IS NOT A JUMP.** `AbilityRules.aim` clamps the *length* of a
## client's direction and cannot stop it pointing upward; a dash with a vertical
## component would be a manoeuvre nobody tuned.
func test_the_dash_is_horizontal_however_the_client_aimed() -> void:
	_press(Vector3(0.0, 1.0, 0.3).normalized())
	_advance(Tuning.ticks(&"TUN-LUNGE-WINDUP"))
	var pawn := _ctx.pawn_contexts[A] as PawnContext
	assert_almost_eq(pawn.velocity.y, 0.0, 0.001, "the dash launched the pawn upward")


## **`TUN-LUNGE-STARTLE-RADIUS` 7.0 m COVERS A 6.0 m DASH FROM EITHER END**, which
## is what US-0070's sixth criterion — *"startles NPCs within 7 m along the dash
## path"* — actually requires of a single wave. Measured rather than claimed: the
## radius and the distance are both tunables and either could move.
func test_one_startle_wave_covers_the_whole_dash_path() -> void:
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	var waves: Array = []
	_system.ability_startled.connect(func(at: Vector3, r: float) -> void: waves.append([at, r]))
	_press()
	_advance(Tuning.ticks(&"TUN-LUNGE-WINDUP"))
	assert_eq(waves.size(), 1, "the dash startled nobody")
	var centre: Vector3 = waves[0][0]
	var radius: float = waves[0][1]
	for step: int in 11:
		var along := Vector3(0.0, 0.0, data.distance * float(step) / 10.0)
		assert_lte(
			centre.distance_to(along),
			radius,
			"the dash path leaves the startle radius %.1f m along it" % along.z
		)


# --- interruption ---------------------------------------------------------


## **STUNNING A LUNGER IS GDD-04 §3.4's NAMED COUNTERPLAY, AND IT MUST NOT ALSO
## COST THEM THE WHIFF.** The stun is the outcome; a stagger on top would price
## the prey's read twice and hand the lunger a second punishment they cannot act
## on. `LungeEffect.end` queues an arrival only when the pawn came back to
## locomotion, which is the one exit `LungingState` takes on its own.
func test_a_lunger_stunned_mid_dash_is_not_also_whiffed() -> void:
	_press()
	_advance(Tuning.ticks(&"TUN-LUNGE-WINDUP"))
	assert_eq(_state(), PawnStateId.LUNGING, "the dash never started")
	var machine := _ctx.pawn_machines[A] as PawnStateMachine
	machine.transition(
		_ctx.pawn_contexts[A] as PawnContext, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT
	)
	_advance(2)
	assert_true(
		_ctx.auto_kill_arrivals.is_empty(), "a stunned lunger still asked SYS-KILL for a kill"
	)


func test_a_completed_dash_queues_exactly_one_arrival() -> void:
	_press()
	_advance(Tuning.ticks(&"TUN-LUNGE-WINDUP"))
	assert_eq(_state(), PawnStateId.LUNGING, "the dash never started")
	_advance(60)
	assert_eq(_state(), PawnStateId.IDLE, "the dash never ended")
	assert_eq(_ctx.auto_kill_arrivals.size(), 1, "a completed dash asked for no kill")
	var row: Array = _ctx.auto_kill_arrivals[0]
	assert_eq(int(row[0]), A, "somebody else's arrival was queued")
	# **THE DASH ORIGIN RIDES WITH THE ARRIVAL**, because `SYS-KILL` judges it over
	# the corridor travelled rather than at the endpoint — and it is recorded at the
	# burst rather than derived from the final yaw, since `LungingState` keeps the
	# camera and a player may have turned.
	#
	# **THE CORRIDOR'S LENGTH CANNOT BE ASSERTED HERE**, and saying so is the point:
	# `LungingState.drives_position()` is false, so a pawn only travels when
	# `PawnMotion` runs `move_and_slide()` — which a unit fixture has no physics for.
	# The origin is therefore the pawn's own position, and the 5.85 m a real dash
	# covers is measured by `tools/lunge_arrival_probe.tscn` on a live server.
	assert_eq(
		row[1] as Vector3,
		(_ctx.pawn_contexts[A] as PawnContext).position,
		"the arrival did not carry the position the dash began at"
	)


## **THE ARRIVAL WAITS FOR THE DASH, NOT FOR A CLOCK OF ITS OWN** — US-0067's
## lesson, applied before it cost anything. `AbilityEffect`'s own `ends_at` fires
## at the derived duration, and if the effect asked for a kill on that alone it
## would ask while the pawn was still mid-air. Here nothing steps the pawn, so the
## state never ends, and the effect must stay silent however long it is ticked.
func test_a_dash_still_running_asks_for_nothing() -> void:
	_press()
	_advance(Tuning.ticks(&"TUN-LUNGE-WINDUP"))
	_advance(120, false)
	assert_eq(_state(), PawnStateId.LUNGING, "the fixture stopped holding the dash open")
	assert_true(_ctx.auto_kill_arrivals.is_empty(), "the effect asked on its own clock")
