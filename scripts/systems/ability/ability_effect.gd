## **ONE SUBCLASS PER ABILITY, AND THE ONLY PER-ABILITY CODE THERE IS.**
## TDD-09 §3, US-0066. SERVER ONLY — effects mutate authoritative state.
##
## Everything else about an ability — timing, cost, cooldown, tell radius,
## counterplay flags — is `AbilityData`, which is why §5 can promise a new ability
## in three files. **Presentation reacts to `NET-S2C-ABILITY-STARTED`, never to
## this class**, so an effect that forgot to broadcast would be invisible rather
## than half-visible.
##
## **THE BASE IS A WORKING NO-OP, NOT AN ABSTRACT.** `AbilityData.effect_script` is
## null for all four abilities until US-0067 to US-0070 fill it in, and a pipeline
## that refused to run without one would be a pipeline nobody could test until the
## first effect existed. What a null script gets is the full pipeline — validation,
## cooldown, suspicion cost, tell broadcast — and no world change, which is exactly
## what US-0066 delivers.
class_name AbilityEffect
extends RefCounted


## Called after all five validations pass. Apply immediate state here.
func begin(_ctx: MatchContext, _caster: int, _aim: AimData) -> void:
	pass


## Called once per net tick while the effect is live. **Return false to end
## early** — `AbilitySystem` ends it on the same tick, so an effect never runs one
## tick past its own decision.
func tick(_ctx: MatchContext, _dt: float) -> bool:
	return false


## Called on expiry, early end, **or caster death**.
##
## **MUST BE IDEMPOTENT**, and TDD-09 §3 says so for a concrete reason: a caster
## who dies mid-effect triggers both paths — the death sweep and the natural
## expiry that was already scheduled for the same tick. An `end` that halved a
## value or freed a resource twice would be a defect visible only when somebody
## died at the wrong moment, which is the hardest kind to reproduce.
func end(_ctx: MatchContext) -> void:
	pass
