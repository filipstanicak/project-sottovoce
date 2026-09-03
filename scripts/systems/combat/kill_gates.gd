## **EVERY REASON A KILL IS REFUSED BEFORE ANYBODY MEASURES A DISTANCE.**
## US-0060, ADR-0015, extracted 2026-09-03. SERVER ONLY.
##
## Split out of `KillSystem._verdict_for` when the Lunge arrival's corridor
## judgement pushed that file past its 400 lines — **and the seam is honest rather
## than mechanical**: everything here is a fact about the *situation* (a cloud, a
## lockout, an invulnerability, a hiding place) and nothing here knows where
## anybody is standing relative to anybody else. The geometry is `KillRules`'.
##
## **THE ORDER IS THE RULE AND IT IS NOT ALPHABETICAL.** A player refused for the
## reason that is *true* rather than for being a centimetre out of range is a
## player who can learn something; `TUN-STUN-LOCKOUT` is counterplay only if a
## locked-out hunter is told they are locked out (GDD-03 §10.2).
class_name KillGates
extends RefCounted


## `ALLOWED` means *nothing here refuses it* — the geometry has not been asked yet.
static func check(
	ctx: MatchContext,
	peer: int,
	contract: int,
	here: Vector3,
	at_tick: int,
	lockouts: CombatLockouts
) -> KillVerdict.V:
	# **THE CASTER'S OWN CLOUD COUNTS.** An area denial that exempted whoever threw
	# it would be a kill setup rather than a denial (GDD-04 §3.1).
	if here != Vector3.INF and ctx.cinderfall.contains_at(here, at_tick):
		return KillVerdict.V.IN_CINDERFALL
	if lockouts != null and lockouts.is_exiled(peer, contract, ctx.tick):
		return KillVerdict.V.LOCKED_OUT
	# **`TUN-RESPAWN-INVULN`, CHECKED AGAINST THE CONTRACT RATHER THAN THE KILLER.**
	# A player still in `Respawning` is already refused by `_living_others`; this is
	# the second after that, when they are back in `Idle` and standing somewhere
	# they did not choose.
	if lockouts != null and lockouts.is_protected(contract, ctx.tick):
		return KillVerdict.V.TARGET_PROTECTED
	if CombatTargets.is_concealed(ctx.pawn_contexts.get(contract)):
		return KillVerdict.V.TARGET_CONCEALED
	return KillVerdict.V.ALLOWED


## **A CLOUD REFUSAL NAMES NOBODY**, because it is a fact about where the *killer*
## is standing: reporting a target would say *your contract was right there* to a
## player who has learned nothing.
static func names_the_contract(verdict: KillVerdict.V) -> bool:
	return verdict != KillVerdict.V.IN_CINDERFALL
