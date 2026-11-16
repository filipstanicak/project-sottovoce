## **A FIGURE IS TOLD ONLY WHAT ANONYMITY HAS ALREADY BEEN SPENT ON.** US-0109.
##
## ANIMATION_SPEC §1 draws the boundary: everything reachable while Anonymous must
## be identical on a clone, and everything past it need not be. `FigureDirector`
## is the one place a player's state reaches their figure, so it is where that
## boundary is held: **no state a civilian could be mistaken for is an act.**
extends GutTest

## The states a figure shows by walking, standing or sitting — by how its body
## moves, exactly as a civilian's does. `Run` and `Sprint` are in it too: a faster
## gait is read off the speed, and the speed already cost the anonymity.
const WALKED: Array[StringName] = [
	&"Respawning", &"Idle", &"BlendWalk", &"Stroll", &"Run", &"Sprint", &"Blended"
]
const OTHER_SLOT := 2


func test_no_state_reachable_while_anonymous_is_an_act() -> void:
	for state: StringName in [&"Idle", &"BlendWalk", &"Stroll", &"Blended"]:
		assert_eq(
			FigureDirector.act_of(state),
			FigureMotion.Act.NONE,
			"%s is shown as an act a clone never performs" % state
		)


func test_every_state_on_the_wire_is_walked_or_acted_and_never_both() -> void:
	for state: StringName in PawnStateId.ALL:
		var acted: bool = FigureDirector.ACTS.has(state)
		assert_ne(acted, WALKED.has(state), "%s is neither walked nor acted, or both" % state)


func test_every_act_is_for_a_state_that_exists() -> void:
	for state: StringName in FigureDirector.ACTS:
		assert_true(PawnStateId.ALL.has(state), "%s is not a pawn state" % state)
	for state: StringName in WALKED:
		assert_true(PawnStateId.ALL.has(state), "%s is not a pawn state" % state)


func test_a_civilian_flinches_or_stares_and_otherwise_just_moves() -> void:
	assert_eq(FigureDirector.NPC_STARTLE, int(NpcBrain.State.STARTLE))
	assert_eq(FigureDirector.NPC_GAWK, int(NpcBrain.State.GAWK))
	assert_eq(FigureDirector.act_of_npc(NpcBrain.State.STARTLE), FigureMotion.Act.FLINCH)
	assert_eq(FigureDirector.act_of_npc(NpcBrain.State.GAWK), FigureMotion.Act.GAWK)
	for state: int in [NpcBrain.State.STROLL, NpcBrain.State.IDLE, NpcBrain.State.WALKING_GROUP]:
		assert_eq(FigureDirector.act_of_npc(state), FigureMotion.Act.NONE)


func test_another_players_state_reaches_their_figure() -> void:
	var remotes := RemotePawns.new()
	add_child_autofree(remotes)
	var director := FigureDirector.new()
	add_child_autofree(director)
	director.bind(null, null, remotes)
	var snapshot := Snapshot.new()
	snapshot.server_tick = 10
	snapshot.add_remote(OTHER_SLOT, Vector3(5, 0, 5), 0.0, PawnStateId.KILL_ANIM, 0, 0)
	remotes.apply_snapshot(snapshot)
	assert_eq(remotes.state_of(OTHER_SLOT), PawnStateId.KILL_ANIM)
	director._physics_process(1.0 / 60.0)
	var body := remotes.pawn_of(OTHER_SLOT).get_node("PersonaVisuals") as PersonaBody
	assert_eq(body.acting(), FigureMotion.Act.STRIKE)


func test_a_slot_never_described_is_idle() -> void:
	var remotes := RemotePawns.new()
	add_child_autofree(remotes)
	assert_eq(remotes.state_of(5), PawnStateId.IDLE)


func test_a_civilians_startle_reaches_its_figure() -> void:
	var crowd := NpcView.new()
	add_child_autofree(crowd)
	var snapshot := Snapshot.new()
	snapshot.server_tick = 10
	snapshot.add_npc(3, Vector3(4, 0, 4), 0.0, NpcBrain.State.STARTLE, 0)
	snapshot.add_npc(4, Vector3(6, 0, 4), 0.0, NpcBrain.State.STROLL, 0)
	crowd.apply_snapshot(snapshot)
	assert_eq(crowd.body_of(3).acting(), FigureMotion.Act.FLINCH)
	assert_eq(crowd.body_of(4).acting(), FigureMotion.Act.NONE)


func test_a_director_with_nobody_to_direct_does_nothing() -> void:
	var director := FigureDirector.new()
	add_child_autofree(director)
	director._physics_process(1.0 / 60.0)
	assert_true(true, "an unbound director must not fail")
