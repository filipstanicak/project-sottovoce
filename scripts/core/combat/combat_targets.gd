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
static func is_concealed(pawn: PawnContext) -> bool:
	return pawn != null and pawn.blend_state == BlendKind.Kind.PROP_CONCEAL
