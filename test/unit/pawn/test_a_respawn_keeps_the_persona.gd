## **A RESPAWN IS THE SAME PLAYER STANDING UP SOMEWHERE ELSE.** US-0100.
##
## **THIS TEST EXISTS BECAUSE THE RULE HAD ONLY A DOCSTRING.** US-0100's third
## criterion says the deal survives death, `pawn_context.gd` says why in four
## lines — and planting the defect (`persona = &""` inside `reset_for_spawn`) ran
## the **whole unit suite green**. A comment claiming a property is not the
## property; it is the thing that stops anybody checking.
##
## The consequence of getting it wrong is invisible and permanent: the field would
## simply read `&""` again, the portrait would go blank, and `CloneBalance` would
## stop fetching that player's clones — taking their crowd away for the rest of
## the match at the exact moment the crowd matters most, which is GDD-03 §6.3
## rule 5's marked man arriving by accident.
extends GutTest

var _pawn: PawnContext


func before_each() -> void:
	_pawn = PawnContext.new()
	_pawn.peer_id = 5
	_pawn.persona = Ids.PERSONA_LUCERNA


func test_a_respawn_keeps_the_persona() -> void:
	_pawn.reset_for_spawn(Vector3(9.0, 0.0, -4.0), 1.2)
	assert_eq(_pawn.persona, Ids.PERSONA_LUCERNA, "a respawn took the player's identity away")


## The rest of `reset_for_spawn` must still do its job: a test that only pinned
## the persona would pass over a function that had stopped resetting anything.
func test_everything_a_respawn_is_supposed_to_clear_is_still_cleared() -> void:
	_pawn.suspicion = 80.0
	_pawn.stagger_ticks = 12
	_pawn.velocity = Vector3(3.0, 0.0, 3.0)
	_pawn.reset_for_spawn(Vector3(9.0, 0.0, -4.0), 1.2)
	assert_eq(_pawn.suspicion, 0.0, "suspicion survived a respawn")
	assert_eq(_pawn.stagger_ticks, 0, "a stagger survived a respawn")
	assert_eq(_pawn.velocity, Vector3.ZERO, "velocity survived a respawn")
	assert_eq(_pawn.position, Vector3(9.0, 0.0, -4.0), "the spawn point was not taken")


## And the identity the persona sits beside is not reset either, for the same
## reason — `peer_id` names the player, and a respawn does not make a new one.
func test_the_peer_id_survives_too() -> void:
	_pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	assert_eq(_pawn.peer_id, 5, "a respawn renamed the player")
