## **WHO GETS TO LOOK.** GDD-02 §4, US-0021.
##
## Control is retained during `KillAnim`, `Vault` and `Drop`, and removed only
## while `Stunned`. That asymmetry is a design position, not an oversight:
## those three take away your *movement*, and taking the look as well would mean
## the game deciding what you get to witness during the seconds you have least
## control — in a game whose entire subject is watching and being watched.
##
## `Stunned` is the exception because helplessness IS the mechanic. Design law 5
## says the prey must have teeth, and the teeth are not merely that the hunter
## stops moving: for the whole freeze they cannot choose where to look while
## their target walks away. **Never soften this to make hunting feel better.**
extends GutTest

var _machine: PawnStateMachine
var _ctx: PawnContext


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())
	_ctx = PawnContext.new()


func after_each() -> void:
	_machine.free()


func test_the_three_committed_states_keep_the_camera() -> void:
	# Named individually, because a blanket "uninterruptible states lose the
	# camera" rule would sweep all four up and be wrong about three of them.
	for id: StringName in [PawnStateId.KILL_ANIM, PawnStateId.VAULT, PawnStateId.DROP]:
		_ctx.state_id = id
		assert_true(_machine.camera_controlled(_ctx), "%s took the camera away" % id)


func test_being_stunned_takes_the_camera() -> void:
	_ctx.state_id = PawnStateId.STUNNED
	assert_false(_machine.camera_controlled(_ctx), "a stunned player can still look around")


func test_it_is_the_only_state_that_does() -> void:
	# The whole registry, so a state added later cannot quietly join the
	# exception. Losing the camera is the exceptional case and has to stay one.
	var offenders: PackedStringArray = []
	for script: GDScript in PawnStateMachine.REGISTERED:
		var state: PawnState = script.new()
		if state.id() == PawnStateId.STUNNED:
			continue
		if not state.camera_controlled():
			offenders.append(String(state.id()))
	assert_eq(offenders.size(), 0, "these states also take the camera: " + ", ".join(offenders))


func test_climbing_keeps_the_camera_too() -> void:
	# Not named in §4 explicitly, but it is a committed manoeuvre like the vault,
	# and a player pinned to a wall for three seconds most needs to look around.
	_ctx.state_id = PawnStateId.CLIMB
	assert_true(_machine.camera_controlled(_ctx))


func test_an_unregistered_state_leaves_control_with_the_player() -> void:
	# A gap in the registry is not a reason to take someone's camera. Five states
	# are still unimplemented, and the default has to be the harmless one.
	_ctx.state_id = PawnStateId.RESPAWNING
	assert_true(_machine.camera_controlled(_ctx))


func test_the_driver_asks_the_state_rather_than_deciding() -> void:
	# The rule belongs to the pawn's state, which is where GDD-02 §4 puts it. A
	# rig that kept its own list would drift from the state table silently.
	var source := SourceScanner.read("res://scripts/presentation/local_pawn_driver.gd")
	assert_true(
		source.contains("_machine.camera_controlled(ctx)"),
		"the driver does not delegate the camera rule to the state machine"
	)
