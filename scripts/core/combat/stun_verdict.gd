## **WHY A STUN PRESS DID OR DID NOT LAND.** TDD-10 §4, GDD-03 §10, US-0061.
## PURE Core.
##
## **THE CLIENT IS NEVER TOLD WHICH OF THESE IT WAS, AND THAT IS A RULE RATHER
## THAN AN OVERSIGHT.** `NET-S2C-STUN-RESULT` carries `valid:bool`. If a refusal
## reported its reason, a prey could press stun at every stranger who came near
## and read the answers apart — *too calm* means "this one is hunting me and is
## being careful", *wrong target* means "this one is not hunting me". That is a
## free identity probe, and it would defeat GDD-03 §6's whole crowd in about
## fifteen seconds. Every penalised verdict therefore costs **exactly** the same
## thing and looks identical from the outside.
class_name StunVerdict
extends RefCounted

enum V {
	## The stun lands: freeze, forced Exposed, and the pair lockout.
	ALLOWED,
	## Nobody is hunting this player — the `TUN-CONTRACT-REASSIGN-DELAY` breath on
	## their pursuer's side, or a lobby of one.
	NO_PURSUER,
	## **THE GATE.** The pursuer is below `TUN-STUN-MIN-TIER`. GDD-03 §10.2: an
	## Anonymous hunter is unstunnable, so the reward for perfect play is perfect
	## safety and stun is a punishment for a specific mistake rather than a
	## coin-flip defence.
	TOO_CALM,
	## Somebody was in reach and it was not the pursuer. GDD-03 §10.3's anti-spam
	## case, and the target is **not affected at all**.
	WRONG_TARGET,
	## Nobody at all inside range and cone. Flailing at an empty street.
	NO_TARGET,
	## The pursuer was there and too far, measured after the rewind.
	OUT_OF_RANGE,
	## The pursuer was there and outside `TUN-STUN-FACING-CONE`.
	OUT_OF_CONE,
	## **ADR-0013.** The pursuer has already committed to a kill, so nothing saves
	## the victim. Costs the stunner nothing: the press was correct and merely
	## late, and charging for correct play at the last instant is the shape of
	## weakening stun that never-do #13 forbids.
	TARGET_COMMITTED,
	## The stunner is mid-swing, staggered, on cooldown, stunned or dead.
	## **Costs nothing** — a press the game was never going to hear.
	BUSY,
	## **`TUN-RESPAWN-INVULN`.** The pursuer came back on the map less than a second
	## ago. Added US-0062. **Costs nothing**, like `TARGET_COMMITTED`: both are the
	## game refusing a correct press for a reason of its own.
	##
	## It is very nearly unreachable — a respawn reinserts that player into the
	## cycle, so they are almost certainly no longer this prey's pursuer, and their
	## suspicion is zero so `TOO_CALM` would refuse them anyway. It exists so the
	## invulnerability means the same thing to both verbs.
	TARGET_PROTECTED,
}

## The refusals that cost `TUN-STUN-INVALID-STAGGER` and
## `TUN-STUN-INVALID-SUSPICION`.
##
## **FLAILING AT NOTHING IS IN THE LIST, NOT ONLY FLAILING AT SOMEBODY.** GDD-03
## §10.3's stated case is a non-pursuer, but its stated *reason* is that stunning
## everyone who comes near must never be the optimal defensive play — and a press
## at empty air would be free under the narrow reading, so mashing the button
## while walking would cost nothing at all.
##
## **AND `TOO_CALM` IS IN IT FOR THE INDISTINGUISHABILITY ABOVE.** A free probe
## that answered "yes, this one is hunting you, they are just being careful" is
## the crowd deleted.
const PENALISED: Array[V] = [
	V.NO_PURSUER,
	V.TOO_CALM,
	V.WRONG_TARGET,
	V.NO_TARGET,
	V.OUT_OF_RANGE,
	V.OUT_OF_CONE,
]


static func is_allowed(verdict: V) -> bool:
	return verdict == V.ALLOWED


## Does this verdict apply the stagger and `TUN-STUN-INVALID-SUSPICION`?
static func costs_the_stunner(verdict: V) -> bool:
	return PENALISED.has(verdict)


## Does the stunner see *something* happen? Everything but `BUSY`, which is the
## game declining to hear a press it is already busy honouring. GDD-02 §9 failure
## mode 7: whatever the cause, the fix is feedback.
static func plays_a_whiff(verdict: V) -> bool:
	return verdict != V.ALLOWED and verdict != V.BUSY


## For `TEL-STUN-REJECTED` and for test failure messages. **Never sent to a
## client** — see the header.
static func name_of(verdict: V) -> StringName:
	return V.keys()[verdict] as StringName
