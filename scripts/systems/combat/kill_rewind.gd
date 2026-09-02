## **THE WORLD A KILL IS JUDGED AGAINST.** ADR-0010, TDD-04 §8, US-0060.
## SERVER ONLY.
##
## Split out of `KillSystem` at US-0070, when the auto-kill's arrival path pushed
## that file past its 400 lines. **The seam is honest rather than mechanical**:
## everything here answers *"what did the world look like when they committed"*
## and nothing here has an opinion about what happens next.
##
## **ONE OF THE TWO PLACES IN THIS PROJECT THAT REWINDS**; `SYS-STUN` is the
## other, and both go through `RewindClamp` so neither can reach further into the
## past than ADR-0010 allows.
class_name KillRewind
extends RefCounted

## How many rewinds have been performed. **ADR-0010's own compliance line** — the
## cost of lag compensation is the one thing that story could not measure before
## it was built, and a number nobody publishes is a number nobody checks.
var rewinds: int = 0


## The rewound world for `peer` at `at_tick`, gathered within `radius()` of where
## they stood.
##
## **AN ABSENT PAWN GETS AN EMPTY WORLD RATHER THAN A REFUSAL**, because every
## caller then finds no target and rejects for the honest reason — *nobody in
## reach* — instead of for a missing-pawn reason no player could act on.
func world_for(ctx: MatchContext, peer: int, at_tick: int) -> RewoundWorld:
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if pawn == null:
		return RewoundWorld.new()
	rewinds += 1
	return ctx.lag_comp.rewind(at_tick, pawn.position, radius())


## TDD-04 §8.3's optimisation: every entity a kill could involve is inside
## `TUN-CINDERFALL-RADIUS + TUN-KILL-RANGE` of the attacker, which is under ten
## metres rather than ninety-six.
##
## **DERIVED RATHER THAN WRITTEN AS 7.5**, so retuning either moves it. It uses
## the *reach* rather than the bare range, so the validation grace cannot fall
## outside the radius that was gathered for it.
static func radius() -> float:
	var cloud := 0.0
	if Tuning.profile != null:
		var data := Tuning.profile.abilities.get(Ids.ABIL_CINDERFALL) as AbilityData
		cloud = data.radius if data != null else 0.0
	return cloud + KillRules.reach(Tuning.combat)


## Everybody alive who is not `peer`. **A corpse is not a candidate** — it is
## already dead, and offering it would let a second killer claim a kill nobody
## made.
static func living_others(ctx: MatchContext, peer: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for other: int in ctx.pawn_contexts.keys():
		if other == peer:
			continue
		if CombatTargets.is_dead(ctx.pawn_contexts[other] as PawnContext):
			continue
		out.append(other)
	return out
