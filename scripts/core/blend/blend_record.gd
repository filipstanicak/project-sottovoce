## **ONE PLAYER'S BLEND, AS A VALUE.** GDD-03 §4.1, TDD-07 §3, US-0053. PURE.
##
## `BlendSystem` owns a dictionary of these and nothing else survives a tick. It
## is a `RefCounted` rather than a dictionary so the phase machine below can be
## exercised with no crowd, no context and no engine — the entry and exit windows
## are 0.35 s and 0.30 s, and the only way to be sure a window is the length it
## claims is to count its ticks somewhere a test can watch.
##
## **THE PHASE IS NOT ON THE WIRE.** `NETWORK_PROTOCOL` §4 spends four bits on the
## *kind*, and `EVT-BLEND-STATE-CHANGED` carries the same five values —
## `NONE POCKET GROUP PROP_STATIC PROP_CONCEAL`. Entry and exit are timing the
## server owns; what a client is told is which blend it is in, which is what the
## idle animation and the HUD need.
class_name BlendRecord
extends RefCounted

## **ENTERING IS NOT YET BLENDED AND LEAVING IS NO LONGER BLENDED.** GDD-03 §4.1
## says entry is 0.35 s during which "you are vulnerable and visibly
## transitioning" — so the crush cannot have started, or a player would buy
## anonymity for a commitment they have not finished making.
enum Phase { OUT, ENTERING, HELD, LEAVING }

var kind: int = BlendKind.Kind.NONE
var phase: int = Phase.OUT

## Net ticks spent in the current phase.
var phase_ticks: int = 0

## The `CrowdFormations` group index for a `GROUP` blend, or -1.
var group: int = -1

## `TUN-BLEND-SCORE-GRACE` counting down after an exit from `HELD`. Read by
## `SYS-KILL` at initiation to decide `SCORE-BLENDED` (+200).
var grace_ticks: int = 0


## Is the crush running? **Only in `HELD`** — see `Phase`.
func is_crushing() -> bool:
	return phase == Phase.HELD


## Has this player committed to a blend at all? True through entry and exit, which
## is what the wire reports and what the animation follows.
func is_engaged() -> bool:
	return phase != Phase.OUT


## What goes in the snapshot: the kind while engaged, `NONE` otherwise. **Derived
## rather than stored**, so a record whose phase was cleared without its kind
## being cleared cannot put a stale blend on the wire.
func wire_kind() -> int:
	return kind if is_engaged() else BlendKind.Kind.NONE


func enter(new_kind: int, group_index: int) -> void:
	kind = new_kind
	group = group_index
	phase = Phase.ENTERING
	phase_ticks = 0


func hold() -> void:
	phase = Phase.HELD
	phase_ticks = 0


## A deliberate exit: `TUN-BLEND-EXIT-TIME` of standing up, then out.
func leave() -> void:
	phase = Phase.LEAVING
	phase_ticks = 0


## **A BREAK IS NOT AN EXIT.** GDD-03 §4.1.1 lists the pocket scattering among the
## things that *break* the blend, and US-0053's sixth criterion says it must happen
## **that tick** — so there is no 0.30 s of standing up. The player is simply not
## blended any more, which is the honest thing for a condition that has lapsed.
func clear() -> void:
	kind = BlendKind.Kind.NONE
	phase = Phase.OUT
	phase_ticks = 0
	group = -1
