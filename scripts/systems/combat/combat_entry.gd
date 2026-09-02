## **PUTTING A PAWN INTO A STATE, FROM A SYSTEM THAT DECIDED IT SHOULD BE THERE.**
## US-0060, US-0061, extracted at US-0070.
##
## **IT WAS WRITTEN TWICE AND THE TWO COPIES AGREED**, which is the only reason
## nothing had gone wrong: `KillSystem._enter` and `StunSystem._enter` were the
## same fourteen lines, including the same warning text. Two copies of a rule that
## disagreed would have been a kill that lands in one system's costume and not the
## other's — the recurring find in this project, and the one it keeps asking you
## to look for before adding a third.
##
## Not in Core, deliberately: `PawnStateMachine extends Node` and Core is pure by
## law, so a helper taking one may not live there.
class_name CombatEntry
extends RefCounted


## Transition through the pawn's **own machine**, so the graph validates the edge
## rather than the caller assuming it. Returns whether it happened.
##
## **AN ILLEGAL EDGE IS REPORTED, NOT ASSERTED AWAY.** It used to be reachable:
## GDD-02 §3 declared no `Drop -> Dead` and no `StunAnim -> Dead`, so a player
## killed while falling or mid-stun-swing could not enter `Dead` — and
## `KillSystem._land` announced the death anyway, leaving a victim who had been
## scored, corpse-spawned and repaired around **still alive**, because
## `CombatTargets.is_dead` reads `state_id`. Both edges landed 2026-09-02 and
## `test_every_living_state_can_reach_dead` is what keeps every future state
## honest.
static func into(ctx: MatchContext, peer: int, to: StringName, priority: int) -> bool:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	var machine: PawnStateMachine = ctx.pawn_machines.get(peer)
	if pawn == null or machine == null:
		return false
	if not machine.is_valid_edge(pawn.state_id, to):
		Log.warn("no %s -> %s edge in GDD-02 §3" % [pawn.state_id, to], &"pawn")
		return false
	return machine.transition(pawn, to, priority)
