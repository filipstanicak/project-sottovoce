## **`ABIL-CINDERFALL`: THE FIRST ABILITY IN THIS GAME THAT CHANGES THE WORLD.**
## GDD-04 §3.1, TDD-09 §3, US-0067. SERVER ONLY.
##
## A thrown ash-pot bursts into a cloud of radius `TUN-CINDERFALL-RADIUS` 5.0 m
## that blocks line of sight and **forbids kill initiation inside it — including
## the caster's own**. That symmetry is the whole ability: without it the dominant
## play is *cloud, then kill inside it*, and a kill nobody can see is design law
## 3's violation wearing an ability's clothes.
##
## **IT IS ELEVEN LINES BECAUSE EVERYTHING ELSE ALREADY EXISTED AND HAD NO
## CALLER.** `CinderfallVolumes` was built at US-0056 and sharpened at US-0060,
## `DetectionSystem` has consulted it in the project's one line-of-sight query
## since, `KillSystem` has refused initiation inside one since US-0060, and
## `AbilitySystem` has run the pipeline around it since US-0066. `add()` was the
## one entry point with nothing behind it — the same shape `CrowdAlarm.startle_at`
## had through all of M3.
##
## **THE STARTLE IS NOT HERE, AND THAT IS DELIBERATE.**
## `TUN-CINDERFALL-STARTLE-RADIUS` is `AbilityData.startle_radius`, which Lunge
## carries too, so `AbilitySystem` raises it from the data beside the suspicion
## cost. An effect that reached `ctx.crowd` would put crowd knowledge in
## `scripts/systems/ability/` to express a rule two abilities share.
class_name CinderfallEffect
extends AbilityEffect


## **THE CLOUD IS PLACED AT THE AIM POINT, WHICH IS ALREADY CLAMPED.**
## `AbilityRules.aim` bounds it to `TUN-CINDERFALL-THROW-RANGE` 8.0 m, so a client
## asking for 40 m gets a cloud at 8 — GDD-04's *"placeable up to 8.0 m away or at
## your feet"* with no second range check.
##
## **NO GROUND CAST, AND THE SPHERE IS WHY.** The aim point sits at roughly the
## caster's own height and the radius is 5.0 m against a 1.8 m capsule, so the
## volume reaches the street under it either way. A downward raycast here would be
## a seventh query against TDD-07 §4.3's budget of 2-6, to move a sphere centre by
## a metre.
func begin(ctx: MatchContext, _caster: int, aim: AimData) -> void:
	ctx.cinderfall.add(aim.point, ctx.tick)


## **TRUE FOR AS LONG AS THE SYSTEM WILL HAVE IT, AND THE BASE SAYS FALSE.**
##
## `AbilityEffect.tick` returning false is the documented *end early* signal, and
## the base returns it because a no-op's honest lifetime is the tick it began —
## which is exactly the answer that made US-0066's ordering test read "the effect
## never started" when it had in fact finished. **The first effect with a duration
## is the first that must override it**, and forgetting to would not break the
## cloud (`CinderfallVolumes` expires on its own clock) but would make
## `is_effect_active` false for the whole 4 s, which is what `SCORE-MASKED` and
## Second Face's identity swap will read.
##
## The deadline is `AbilitySystem`'s, from `TUN-CINDERFALL-DURATION`. This never
## ends early: a cloud cannot be put out.
func tick(_ctx: MatchContext, _dt: float) -> bool:
	return true


## **NOTHING. AND REMOVING THE CLOUD HERE WOULD BE A DEFECT, NOT TIDINESS.**
##
## US-0067's seventh criterion asks for the volume to be *deregistered on expiry*,
## and `CinderfallVolumes.expire` already does it — but it deliberately lags the
## burn-out by `RewindClamp.max_ticks()`, because a kill is validated in the past
## and a cloud that was up when the attacker pressed must still block that
## validation 100-200 ms later. An `end()` that cleared the volume would delete
## exactly that window, and the symptom would be a kill landing inside a cloud
## that had been up at the moment it was pressed.
##
## Idempotent, as TDD-09 §3 requires: doing nothing twice is doing nothing.
func end(_ctx: MatchContext) -> void:
	pass
