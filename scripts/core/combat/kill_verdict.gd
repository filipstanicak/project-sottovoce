## **WHY A KILL PRESS DID OR DID NOT LAND.** TDD-10 §3, US-0060. PURE Core.
##
## A verdict rather than a bool, because two of the criteria are about the
## *reason*: a rejection costs `TUN-SUSPICION-GAIN-FAILED-KILL` and plays a whiff,
## and a lost contest costs `TUN-KILL-CONTEST-STAGGER` and neither. A bool would
## make those the same outcome, and the difference is the whole of GDD-02 §9's
## failure mode 7 — *"whatever the cause, the fix is feedback: a rejected kill
## must play a distinct whiff, never silence"*.
class_name KillVerdict
extends RefCounted

enum V {
	## The kill lands. `KillAnim` starts; the victim dies at the contact frame.
	ALLOWED,
	## The killer has no announced contract — the `TUN-CONTRACT-REASSIGN-DELAY`
	## breath, or a lobby of one.
	NO_CONTRACT,
	## Somebody was there and it was not the contract. This is the one
	## `TUN-KILL-INVALID-TARGET-PENALTY` is written for.
	WRONG_TARGET,
	## Nobody at all inside range and cone.
	NO_TARGET,
	## The contract was there and too far, measured after the rewind.
	OUT_OF_RANGE,
	## The contract was there and outside `TUN-KILL-FACING-CONE`.
	OUT_OF_CONE,
	## The killer is standing in a cinder cloud — their own counts.
	IN_CINDERFALL,
	## Somebody else's initiation on this victim was earlier.
	LOST_CONTEST,
	## Already mid-kill, staggered, dead or otherwise not in a state that may
	## initiate. **Costs nothing**: a press that the game was never going to hear
	## must not be charged for.
	BUSY,
	## **`TUN-STUN-LOCKOUT`.** This killer stunned by this victim inside the last
	## 12 s, and is exiled from them specifically — they may still hunt anybody
	## else the cycle hands them. Added US-0061.
	##
	## **Costs nothing**, like `BUSY`: the exile is already the punishment, and
	## charging suspicion on top would let a stunned hunter be pushed further
	## Exposed by pressing a button that does nothing.
	LOCKED_OUT,
}

## The rejections that cost `TUN-SUSPICION-GAIN-FAILED-KILL` and play the whiff —
## TDD-10 §3's `Z2`, which is every branch below the Cinderfall gate.
##
## **`IN_CINDERFALL` IS NOT ONE**, and that is the flowchart's own shape: the
## cloud gate is `Z1`, a separate terminal with no penalty attached. A cinder
## cloud denies the area; it does not additionally advertise you for having stood
## in it.
const PENALISED: Array[V] = [
	V.NO_CONTRACT,
	V.WRONG_TARGET,
	V.NO_TARGET,
	V.OUT_OF_RANGE,
	V.OUT_OF_CONE,
]


static func is_allowed(verdict: V) -> bool:
	return verdict == V.ALLOWED


## Does this verdict apply `TUN-SUSPICION-GAIN-FAILED-KILL`?
static func costs_suspicion(verdict: V) -> bool:
	return PENALISED.has(verdict)


## Does the killer see *something* happen? Everything except `BUSY`, which is the
## game declining to hear a press it is already busy honouring.
static func plays_a_whiff(verdict: V) -> bool:
	return verdict != V.ALLOWED and verdict != V.BUSY


## For `TEL-KILL-REJECTED` and for test failure messages. Not user-facing — no
## string in this project outside `data/strings/en.csv` is.
static func name_of(verdict: V) -> StringName:
	return V.keys()[verdict] as StringName
