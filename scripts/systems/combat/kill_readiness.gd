## **WOULD A PRESS RIGHT NOW LAND?** GDD-06 §4, US-0060, US-0065. SERVER ONLY.
##
## The reticle hint, split out of `KillSystem` when that file reached its 400-line
## ceiling (never-do #6). **The seam is a real one**: judging a press is the
## server's authority over an outcome, and answering *would it land* is a hint
## drawn on one player's own screen about their own position. `StunSystem` keeps
## `stun_ready` for the same reason and this is its counterpart.
##
## **PRESENT TENSE, NOT REWOUND.** Rewinding it would make the reticle disagree
## with what the player can see in front of them.
##
## **AND IT CANNOT BE MORE PERMISSIVE THAN THE PRESS**, which is the whole risk of
## having two functions answer one question: a hint that promised a kill the
## verdict then refuses is GDD-02 §9's failure mode 7 with the game's own HUD as
## the liar. Every gate here has a counterpart in `KillSystem._verdict_for`, and
## `test_kill_ready_never_lies.gd` sweeps the two against each other.
class_name KillReadiness
extends RefCounted


## Write the hint onto every pawn. **After the presses, not before**: a killer who
## has just committed must see the reticle close, and computing it first would
## leave it open for the whole 1.4 s of an animation they cannot act during.
static func publish(
	ctx: MatchContext, lockouts: CombatLockouts, sight: Callable, busy: Callable
) -> void:
	for peer: int in ctx.pawn_contexts.keys():
		(ctx.pawn_contexts[peer] as PawnContext).kill_ready = of(peer, ctx, lockouts, sight, busy)


static func of(
	peer: int, ctx: MatchContext, lockouts: CombatLockouts, sight: Callable, busy: Callable
) -> bool:
	var here: PawnContext = ctx.pawn_contexts.get(peer)
	var contract := int(ctx.announced_contracts.get(peer, ContractCycle.NOBODY))
	if here == null or contract == ContractCycle.NOBODY or bool(busy.call(ctx, peer)):
		return false
	var target: PawnContext = ctx.pawn_contexts.get(contract)
	if target == null or CombatTargets.is_dead(target):
		return false
	if lockouts != null and lockouts.is_exiled(peer, contract, ctx.tick):
		return false
	if lockouts != null and lockouts.is_protected(contract, ctx.tick):
		return false
	if CombatTargets.is_concealed(target):
		return false
	var t := Tuning.combat
	return (
		KillRules.in_reach(here.position, target.position, t)
		and KillRules.within_cone(here.position, here.yaw, target.position, t)
		# **THE HINT CARRIES THE SIGHT GATE TOO**, or the reticle would promise a
		# kill through a stall that the press refuses — `stun_ready`'s lesson.
		and KillRules.can_see(sight, here.position, target.position)
	)
