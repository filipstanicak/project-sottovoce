## **WHETHER A PAWN CAN BE A TARGET AT ALL.** GDD-03 §4.1.4, ADR-0015. PURE Core.
##
## Two questions both combat systems ask and nothing else does. They lived in
## `KillSystem` as private statics, and **the concealment rule was then written a
## second time inline in `StunSystem`** — the recurring find in this project, and
## the reason it matters here is that the two copies must agree forever: a target
## the kill refuses and the stun accepts is an inconsistency a player would read
## as a hiding spot that works against one verb and not the other.
class_name CombatTargets
extends RefCounted


## Dead or on the way back. `Respawning` counts: the pawn exists, holds a
## position and is not available to be killed again.
static func is_dead(pawn: PawnContext) -> bool:
	return pawn.state_id == PawnStateId.DEAD or pawn.state_id == PawnStateId.RESPAWNING


## **GDD-03 §4.1.4's *"a player inside cannot be killed"*** — the one exception to
## *blend protects anonymity, never the body*, and it is the GDD's rather than
## this project's convenience.
##
## **Read off the pawn**, whose `blend_state` is written at the `suspicion` stage
## and read here at `combat`, three stages later in the same tick.
## **CAN THIS PLAYER START ANYTHING RIGHT NOW.** GDD-03 §10, US-0060, moved here
## at US-0070 when `KillSystem` passed its 400 lines.
##
## Already killing, dead, stunned, mid-stun-swing, or serving a stagger.
## **Costs nothing** — the press was never going to be heard, and charging for it
## would let a stagger compound itself.
##
## **THE TWO NON-PAWN FACTS ARE ARGUMENTS RATHER THAN LOOKUPS**, which is what
## keeps this in Core: `committed` is the caller's own pending table and
## `staggered` is `CombatLockouts`', and a predicate that reached for either could
## not be asked a question in a test.
##
## **AN ABSENT PAWN IS BUSY**, because the safe answer to *"may this player act"*
## for somebody who is not in the world is no.
static func is_busy(pawn: PawnContext, committed: bool, staggered: bool) -> bool:
	if committed or staggered or pawn == null:
		return true
	if pawn.state_id == PawnStateId.KILL_ANIM or pawn.state_id == PawnStateId.STUNNED:
		return true
	if pawn.state_id == PawnStateId.STUN_ANIM:
		return true
	return is_dead(pawn)


static func is_concealed(pawn: PawnContext) -> bool:
	return pawn != null and pawn.blend_state == BlendKind.Kind.PROP_CONCEAL
