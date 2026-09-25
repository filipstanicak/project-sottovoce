## **THE CLOUD CATCHES EVERYBODY IN IT BUT THE CASTER.** ADR-0023, US-0104. SERVER
## ONLY.
##
## The reference's cloud makes everyone inside it double over coughing, unable to
## run or fight back, for as long as it stands, including anybody who walks in
## after the burst, and a pursuer caught in it is a free stun. So, every tick:
##
## 1. **The caster's own pursuer, inside the caster's own cloud, is stunned by the
##    caster**: `SCORE-STUN` and the contract loss (ADR-0019), everything a pressed
##    stun does except the swing.
## 2. **Anybody else inside a cloud they did not throw starts choking**, from
##    locomotion. A stagger, a traversal or a committed action finishes first and is
##    caught the tick after, which is also why there is no edge for it.
## 3. **A choking pawn no cloud holds any more is released** into `Idle`.
##
## **RE-DECIDED EVERY TICK FROM THE CLOUDS, NEVER REMEMBERED.** The same choice
## `SYS-BLEND` makes for a blend: a catch that was stored would outlive a cloud
## whose caster died, and a release that was scheduled would miss the second cloud
## thrown over the first. Nothing here holds state, so nothing here can drift.
##
## NPCs are held by `CrowdDirector` from the same clouds, so the cloud does not
## name the players in it (clone parity, GDD-03 §6.5).
class_name CinderfallCatch
extends RefCounted

const CATCHABLE: Array[StringName] = [
	PawnStateId.IDLE,
	PawnStateId.BLEND_WALK,
	PawnStateId.STROLL,
	PawnStateId.RUN,
	PawnStateId.SPRINT,
]


static func tick(ctx: MatchContext, stun: StunSystem) -> void:
	if ctx.cinderfall == null:
		return
	var radius := ctx.cinderfall.radius()
	for cloud: Array in ctx.cinderfall.alight(ctx.tick):
		stun.stun_from_cloud(ctx, int(cloud[1]), cloud[0] as Vector3, radius)
	for peer: int in ctx.pawn_contexts.keys():
		var pawn: PawnContext = ctx.pawn_contexts[peer]
		var held := ctx.cinderfall.catches(pawn.position, peer, ctx.tick)
		if held and pawn.state_id in CATCHABLE:
			CombatEntry.into(ctx, peer, PawnStateId.CHOKING, PawnState.PRIORITY_COMBAT)
		elif not held and pawn.state_id == PawnStateId.CHOKING:
			CombatEntry.into(ctx, peer, PawnStateId.IDLE, PawnState.PRIORITY_COMBAT)
